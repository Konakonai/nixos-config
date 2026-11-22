{
  config,
  hostProfile,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # "lilya_lckstar喜欢的音乐" on NetEase; public, readable without login.
  likedPlaylist = "2331288123";
  discoverPython = pkgs.python3.withPackages (p: [
    p.opencc
    p.ytmusicapi
  ]);
in
{
  # NetEase web login (the MUSIC_U cookie) for music-discover, which runs as
  # the user. It expires every few months.
  age.secrets.netease-cookie = {
    file = ../../secrets/netease-cookie.age;
    owner = hostProfile.user.userName;
    group = hostProfile.user.group;
    mode = "0400";
  };

  home-manager.users.${hostProfile.user.userName} =
    hmArgs:
    let
      hmConfig = hmArgs.config;
      stateDir = "${hmConfig.xdg.stateHome}/music-discover";

      # Deezer's search API returns empty results from mainland IPs, but album
      # lookups work. Deezer downloads carry the album UPC in BARCODE, so resolve
      # it to a Deezer album ID and pin the import to that release.
      beet-deezer = pkgs.writeShellApplication {
        name = "beet-deezer";
        runtimeInputs = with pkgs; [
          hmConfig.programs.beets.package
          curl
          flac
          jq
        ];
        # --noincremental: downloads land in the same folder every time, and
        # incremental mode skips any folder it has imported from before.
        text = ''
          if [ "$#" -eq 0 ]; then
            echo "usage: beet-deezer <album-dir>..." >&2
            exit 1
          fi

          for dir in "$@"; do
            # One UPC per call: a download folder holding several releases would
            # otherwise all be pinned to the first file's album.
            upcs=$(
              find "$dir" -maxdepth 1 -name '*.flac' -exec metaflac --show-tag=BARCODE {} + 2>/dev/null |
                cut -d= -f2- | sort -u
            )
            if [ "$(printf '%s' "$upcs" | grep -c .)" -gt 1 ]; then
              echo "$dir: files from several releases (UPCs: $(paste -sd " " <<<"$upcs")); split them into one folder per album" >&2
              continue
            fi
            upc=$upcs
            id=""
            if [ -n "$upc" ]; then
              id=$(curl -fsS --retry 3 "https://api.deezer.com/album/upc:$upc" | jq -r '.id // empty')
            fi

            if [ -n "$id" ]; then
              echo "$dir -> https://www.deezer.com/album/$id"
              beet import --noincremental --search-id "$id" "$dir"
            else
              echo "$dir: no Deezer album for UPC '$upc', falling back to search" >&2
              beet import --noincremental "$dir"
            fi
          done
        '';
      };

      # Mirror the library to the Navidrome server (see docs/music-server.md).
      # Navidrome's watcher misses rsync's temp-file-and-rename writes, and its
      # incremental scan goes by folder mtimes, which tag-only edits (new lyrics)
      # don't touch, so run a full scan whenever anything changed.
      music-sync = pkgs.writeShellApplication {
        name = "music-sync";
        runtimeInputs = with pkgs; [
          openssh
          rsync
        ];
        text = ''
          src="${hmConfig.programs.beets.settings.directory}/"
          remote=shanghai
          dest=/srv/music/

          rsync_args=()
          if [ "''${1:-}" = "-n" ]; then
            rsync_args+=(--dry-run)
          fi

          # --delete on an empty source would wipe the server's copy.
          if [ -z "$(find "$src" -type f -print -quit)" ]; then
            echo "music-sync: $src is empty, refusing to mirror it" >&2
            exit 1
          fi

          changes=$(
            rsync -a --delete --delete-delay --partial --chmod=D755,F644 \
              --out-format='%i %n' "''${rsync_args[@]}" "$src" "$remote:$dest" |
              grep -v '^\.d' || true
          )
          if [ -z "$changes" ]; then
            echo "music-sync: already up to date"
            exit 0
          fi
          printf '%s\n' "$changes"

          if [ "''${#rsync_args[@]}" -gt 0 ]; then
            exit 0
          fi
          echo "music-sync: rescanning library on $remote"
          ssh "$remote" runuser -u navidrome -- /opt/navidrome/navidrome scan --full \
            -c /etc/navidrome/navidrome.toml --nobanner 2>&1 | grep -i 'finished\|error' || true
        '';
      };

      # Runs on the laptop, not the server: YouTube Music is only reachable
      # through mihomo. The page is then served by the Navidrome nginx at
      # https://106.14.0.229:8443/discover/ (see docs/music-server.md).
      music-discover = pkgs.writeShellApplication {
        name = "music-discover";
        runtimeInputs = with pkgs; [
          openssh
          rsync
        ];
        text = ''
          ${discoverPython}/bin/python3 ${inputs.lilya-tools}/music-discover/music-discover.py \
            --playlist ${likedPlaylist} \
            --library-db ${hmConfig.programs.beets.settings.library} \
            --state ${stateDir} \
            --out ${stateDir}/site \
            --cookie-file ${config.age.secrets.netease-cookie.path}
          rsync -a --chmod=D755,F644 ${stateDir}/site/ shanghai:/var/www/discover/
          echo "music-discover: https://106.14.0.229:8443/discover/"
        '';
      };
    in
    {
      home.packages = [
        beet-deezer
        music-sync
        music-discover
        # badfiles shells out to `flac -wst` to verify downloads.
        pkgs.flac
      ];

      programs.beets = {
        enable = true;
        # zhlyrics is a local plugin loaded from pluginpath; this only pulls its
        # OpenCC dependency into beets' Python environment.
        package =
          with pkgs.python3Packages;
          toPythonApplication (
            beets.override {
              pluginOverrides.zhlyrics = {
                enable = true;
                propagatedBuildInputs = [ opencc ];
              };
            }
          );

        settings = {
          directory = "${hmConfig.home.homeDirectory}/Music";
          # Keep the database out of the library so syncing ~/Music to the
          # streaming server only ships audio, art and nothing machine-local.
          library = "${hmConfig.xdg.dataHome}/beets/library.db";

          pluginpath = [ "${inputs.lilya-tools}/beets-zhlyrics" ];
          plugins = [
            "musicbrainz"
            "deezer"
            "fetchart"
            "embedart"
            "lyrics"
            "zhlyrics"
            "replaygain"
            "ftintitle"
            "inline"
            "badfiles"
            "duplicates"
            "missing"
            "unimported"
            "mbsync"
            "edit"
            "info"
            "fromfilename"
          ];

          import = {
            move = true;
            write = true;
            incremental = true;
            # Don't remember skipped directories, so they can be retried later.
            incremental_skip_later = true;
            duplicate_action = "ask";
            # Prefer Chinese artist/title aliases from MusicBrainz, then English.
            languages = [
              "zh"
              "en"
            ];
            log = "${hmConfig.xdg.dataHome}/beets/import.log";
          };

          match = {
            preferred = {
              media = [ "Digital Media" ];
              countries = [
                "CN"
                "TW"
                "HK"
                "XW"
              ];
              original_year = true;
            };
          };

          # Keep CJK characters in paths; only replace characters that break
          # on common filesystems.
          asciify_paths = false;

          item_fields.disc_prefix = "f'{disc}-' if disctotal > 1 else ''";

          paths = {
            default = "$albumartist/$album%aunique{}/$disc_prefix$track $title";
            comp = "Various Artists/$album%aunique{}/$disc_prefix$track $title";
            singleton = "$artist/Singles/$title";
          };

          musicbrainz.external_ids.deezer = true;
          # Deezer is the primary source, so don't rank its releases below
          # MusicBrainz just for coming from a different data source.
          deezer.data_source_mismatch_penalty = 0.0;

          fetchart = {
            # cover_art_url is the artwork URL returned by the Deezer source.
            sources = [
              "filesystem"
              "cover_art_url"
              "coverart"
              "itunes"
            ];
            minwidth = 500;
            enforce_ratio = true;
            high_resolution = true;
          };

          # Navidrome serves the full-size cover.jpg; the embedded copy only
          # needs to be large enough for players that ignore folder art.
          embedart.maxwidth = 1000;

          lyrics = {
            synced = true;
            # netease is registered by zhlyrics and covers Chinese releases far
            # better than LRCLib. Genius rarely has Chinese lyrics and rate-limits
            # hard (429 with long backoff on every miss), so it is left out.
            sources = [
              "netease"
              "lrclib"
            ];
          };

          replaygain = {
            backend = "ffmpeg";
            auto = true;
          };

          badfiles.check_on_import = true;
        };
      };

      systemd.user.services.music-discover = {
        Unit.Description = "Build the weekly music discovery page";
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe music-discover;
        };
      };

      systemd.user.timers.music-discover = {
        Unit.Description = "Weekly music discovery page";
        Timer = {
          OnCalendar = "Mon 09:00";
          # Catch up after the laptop was off at the scheduled time.
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
