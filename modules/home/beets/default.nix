{ config, pkgs, ... }:

let
  # Deezer's search API returns empty results from mainland IPs, but album
  # lookups work. Deezer downloads carry the album UPC in BARCODE, so resolve
  # it to a Deezer album ID and pin the import to that release.
  beet-deezer = pkgs.writeShellApplication {
    name = "beet-deezer";
    runtimeInputs = with pkgs; [
      config.programs.beets.package
      curl
      flac
      jq
    ];
    text = ''
      if [ "$#" -eq 0 ]; then
        echo "usage: beet-deezer <album-dir>..." >&2
        exit 1
      fi

      for dir in "$@"; do
        track=$(find "$dir" -maxdepth 1 -name '*.flac' -print -quit)
        upc=$(metaflac --show-tag=BARCODE "$track" 2>/dev/null | head -n1 | cut -d= -f2-)
        id=""
        if [ -n "$upc" ]; then
          id=$(curl -fsS --retry 3 "https://api.deezer.com/album/upc:$upc" | jq -r '.id // empty')
        fi

        if [ -n "$id" ]; then
          echo "$dir -> https://www.deezer.com/album/$id"
          beet import --search-id "$id" "$dir"
        else
          echo "$dir: no Deezer album for UPC '$upc', falling back to search" >&2
          beet import "$dir"
        fi
      done
    '';
  };
in

{
  home.packages = [
    beet-deezer
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
      directory = "${config.home.homeDirectory}/Music";
      # Keep the database out of the library so syncing ~/Music to the
      # streaming server only ships audio, art and nothing machine-local.
      library = "${config.xdg.dataHome}/beets/library.db";

      pluginpath = [ "${./plugins}" ];
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
        log = "${config.xdg.dataHome}/beets/import.log";
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
        # Genius rarely has Chinese lyrics and rate-limits hard (429 with
        # long backoff on every miss), so only LRCLib is queried.
        sources = [ "lrclib" ];
      };

      replaygain = {
        backend = "ffmpeg";
        auto = true;
      };

      badfiles.check_on_import = true;
    };
  };
}
