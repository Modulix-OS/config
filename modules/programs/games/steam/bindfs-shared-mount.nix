{ config, pkgs, lib, ... }:
let
  cfg = config.mx.programs.games;
  gamersGid = toString config.users.groups.gamers.gid;
  gamersMembers = config.users.groups.gamers.members;
in
{
  config = lib.mkIf (cfg.enable && cfg.shared_steam_dir != null) {
    environment.systemPackages = [ pkgs.bindfs ];
    systemd.services = lib.mkMerge (map (user:
      let
        home = config.users.users.${user}.home;
        target = "${home}/Shared_Games";
      in {
        "mx-steam-shared-common-${user}" = {
          description = "Bindfs mount of shared Steam common dir for ${user}, root:gamers preserved on disk";
          after = [ "local-fs.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${target}";
            ExecStart = ''
              ${pkgs.bindfs}/bin/bindfs \
                --map=root/${user} \
                --create-for-user=0 --create-for-group=${gamersGid} \
                --enable-lock-forwarding \
                -o allow_other,x-gvfs-hide \
                -o attr_timeout=300,entry_timeout=300,negative_timeout=300 \
                -o kernel_cache \
                --multithreaded \
                -f \
                ${cfg.shared_steam_dir} \
                ${target}
            '';
            ExecStop = "${pkgs.fuse}/bin/fusermount -u ${target}";
            Restart = "on-failure";
          };
        };
      }
    ) gamersMembers);
  };
}
