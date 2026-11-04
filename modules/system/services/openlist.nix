{ hostProfile, pkgs, ... }:

let
  dbFile = "${hostProfile.services.openlistDataDir}/data.db";
in
{
  systemd.services.openlist = {
    description = "OpenList Service";
    after = [ "mihomo.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      # Cloud storages are initialised once at startup and stay broken if DNS
      # isn't up yet (mihomo being started doesn't mean it resolves), which
      # makes every WebDAV listing return 500. Wait up to 60 s, then start
      # anyway so an offline boot isn't held up.
      ExecStartPre = [
        (pkgs.writeShellScript "openlist-wait-dns" ''
          for _ in $(${pkgs.coreutils}/bin/seq 60); do
            ${pkgs.getent}/bin/getent hosts drive.quark.cn >/dev/null && exit 0
            ${pkgs.coreutils}/bin/sleep 1
          done
          echo "DNS still not ready after 60 s, starting OpenList anyway" >&2
        '')
        # OpenList asks for WAL with mattn's `_journal=WAL`, which the
        # glebarez driver it's built with ignores, so the DB stayed in
        # rollback-journal mode. A driver token refresh then hit SQLITE_BUSY
        # against WebDAV reads and leaked its transaction, and every request
        # failed until restart (10-30, 11-03, 11-04). journal_mode=WAL is
        # stored in the file; re-applying it each start covers a restored DB.
        (pkgs.writeShellScript "openlist-db-wal" ''
          [ -f ${dbFile} ] || exit 0
          ${pkgs.sqlite}/bin/sqlite3 ${dbFile} 'PRAGMA journal_mode=WAL;' >/dev/null
        '')
      ];
      ExecStart = "${pkgs.openlist}/bin/OpenList server --data ${hostProfile.services.openlistDataDir}";
      Restart = "always";
      User = hostProfile.user.userName;
      Group = hostProfile.user.group;
    };
  };
}
