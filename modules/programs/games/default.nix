{ config, pkgs, pkgs-unstable, lib, ... }:

let
  cfg = config.mx.programs.games;
  cgpu = config.mx.hardware.gpu;

  proton-cachyos = pkgs.callPackage ../../../pkgs/proton-cachyos.nix { arch=pkgs.stdenv.hostPlatform.system; };
  proton-ge = pkgs.callPackage ../../../pkgs/proton-ge.nix { arch=pkgs.stdenv.hostPlatform.system; };

  protonTools = [ proton-cachyos proton-ge ];

  protonCompatTools = pkgs.linkFarm "mx-proton-compat-tools" (
    map (p: { name = p.dirName; path = p.steamcompattool; }) protonTools
  );

  normalUsers = import ../../../lib/normal-user.nix { inherit config; };

  gameServices = import ../../../lib/mx-game-services.nix { inherit lib config; };

  mx-game = import ../../../pkgs/mx-game.nix {
    inherit lib pkgs;
    services = gameServices.enabledUnits;
    fwFanCtrl = config.mx.hardware.framework-fan-ctrl.enable;
    desktop = config.mx.desktop;
    enableHDR = cfg.enableHDR;
    obsCapture = config.mx.programs.studio.obs-studio.enable;
  };

  mangohudStyleBase = ''
    legacy_layout=0
    round_corners=0
    background_color=000000
    font_size=24
    text_color=FFFFFF
    gpu_text=GPU
    cpu_text=CPU
    gpu_color=2E9762
    cpu_color=2E97CB
    vram_color=AD64C1
    ram_color=C26693
    battery_color=00FF00
    engine_color=EB5B5B
    wine_color=EB5B5B
    frametime_color=00FF00
  '';

  mangohudStyleBar = ''
    ${mangohudStyleBase}
    horizontal
    hud_no_margin
    table_columns=1
    position=top-center
    background_alpha=0
  '';

  mangohudStylePanel = ''
    ${mangohudStyleBase}
    position=top-left
    background_alpha=0.4
  '';

  mangohudElementsFps = ''
    fps
    time
  '';

  mangohudElementsBasic = ''
    gpu_stats
    cpu_stats
    vram
    ram
    battery
    fps
    frame_timing
    time
  '';

  mangohudElementsDetailed = ''
    gpu_stats
    gpu_temp
    gpu_core_clock
    gpu_mem_clock
    gpu_power
    cpu_stats
    cpu_temp
    cpu_mhz
    cpu_power
    vram
    ram
    battery
    fps
    frametime
    frame_timing
    time
  '';

  mangohudElementsFull = ''
    gpu_name
    gpu_stats
    gpu_temp
    gpu_junction_temp
    gpu_mem_temp
    gpu_core_clock
    gpu_mem_clock
    gpu_power
    gpu_fan
    gpu_voltage
    cpu_stats
    cpu_temp
    cpu_mhz
    cpu_power
    core_load
    core_bars
    core_type
    vram
    ram
    swap
    procmem
    io_read
    io_write
    battery
    fps
    frametime
    fps_metrics=avg,0.01
    frame_timing
    throttling_status
    resolution
    refresh_rate
    vulkan_driver
    engine_version
    arch
    wine
    time
  '';

  mangohudPresets = pkgs.writeText "mangohud-presets.conf" ''
    [preset 1]
    ${mangohudStyleBar}
    ${mangohudElementsFps}

    [preset 2]
    ${mangohudStyleBar}
    ${mangohudElementsBasic}

    [preset 3]
    ${mangohudStylePanel}
    ${mangohudElementsDetailed}

    [preset 4]
    ${mangohudStylePanel}
    ${mangohudElementsFull}
  '';


in
{

  imports = [
    ./steam
    ./lutris
    ./heroic
    ./umu
  ];

  options.mx.programs.games = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.steam.enable || cfg.lutris.enable || cfg.heroic.enable || cfg.umu.enable;
      description = "Whether shared gaming config is active (auto: any launcher enabled).";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Users added to the 'gamers' group.";
    };

    game_lib_dirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Folder with games shared for all gamers user";
    };

    shared_steam_dir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/mnt/Games/SteamLibrary";
      description = ''
        Directory on the shared disk holding the Steam data common to every gamer.
        Inside the Steam wrapper, `<dir>/common` is bind-mounted onto
        `~/.local/share/Steam/steamapps/common`, so the installed games are shared,
        and `<dir>/work/<user>/{downloading,temp,shadercache}` onto their
        counterparts, so downloads are staged on the same filesystem as the games
        and land with a rename instead of a copy across partitions.

        Everything else stays in each user home, Proton prefixes first: Wine
        refuses a prefix it does not own.
      '';
    };

    latest-unstable-mesa-driver.enable = lib.mkEnableOption "Enable latest unstable Mesa driver";

    enableHDR = lib.mkEnableOption "Enable HDR on games";
  };

  config = lib.mkIf cfg.enable {
    programs = {
      gamescope = {
        enable = true;
        package = lib.mkMxDefault pkgs.gamescope;

        capSysNice = lib.mkMxDefault true;
      };
      gamemode = {
        enable = true;
        settings = {
          general.renice = lib.mkMxDefault 10;
          gpu = {
            amd_performance_level = lib.mkIf (cgpu.vendor == "amd") (lib.mkMxDefault "high");
            nv_powermizer_mode = lib.mkIf (cgpu.vendor == "nvidia") (lib.mkMxDefault 1);
          };
        };
      };
    };

    environment = {
      sessionVariables = {
        STEAM_EXTRA_COMPAT_TOOLS_PATHS = "${protonCompatTools}:\${HOME}/.steam/root/compatibilitytools.d";

        MANGOHUD_PRESETSFILE = "/etc/MangoHud/presets.conf";
        MANGOHUD_CONFIG = lib.concatStringsSep "," [
          "control=mangohud"
          "gpu_list=0"
          "preset=0\\,1\\,2\\,3\\,4"
          "toggle_preset=Shift_R+F10"
          "toggle_hud=Shift_R+F12"
          "toggle_hud_position=Shift_R+F11"
          "toggle_fps_limit=Shift_L+F1"
          "fps_limit_method=late"
          "fps_limit=0\\,165\\,60\\,30"
        ];

        MESA_SHADER_CACHE_MAX_SIZE= lib.mkIf (cgpu.vendor == "amd") "12G";
        __GL_SHADER_DISK_CACHE_SIZE= lib.mkIf (cgpu.vendor == "nvidia") "12000000000";

      };

      etc."MangoHud/presets.conf".source = mangohudPresets;
    };
    environment.systemPackages = [
      pkgs.mangohud
      pkgs-unstable.vkbasalt
      pkgs.goverlay
      mx-game
    ] ++ protonTools;

    systemd.user.tmpfiles.rules = [
      "d %h/.local/share/Steam/compatibilitytools.d 0755 - - -"
    ] ++ map (p:
      "L+ %h/.local/share/Steam/compatibilitytools.d/${p.dirName} - - - - ${p.steamcompattool}"
    ) protonTools;
    hardware = {
        graphics = {
          enable = true;
          enable32Bit = lib.mkMxDefault true;
          package = lib.mkMxDefault (if cfg.latest-unstable-mesa-driver.enable then pkgs-unstable.mesa else pkgs.mesa);
          package32 = lib.mkMxDefault (if cfg.latest-unstable-mesa-driver.enable then pkgs-unstable.pkgsi686Linux.mesa else pkgs.pkgsi686Linux.mesa);
        };
    };

    users.groups = {
      gamers.members = cfg.users;
    };

    users.users = lib.mkMerge (map (user: {
      ${user}.extraGroups = [ "gamemode" ];
    }) cfg.users);

    systemd.tmpfiles.rules =
    let
      acl = lib.concatStringsSep "," [
        "user::rwX"
        "group::rwX"
        "group:gamers:rwX"
        "mask::rwX"
        "other::---"
        "default:user::rwx"
        "default:group::rwx"
        "default:group:gamers:rwx"
        "default:mask::rwx"
        "default:other::---"
      ];
      mkRules = owner: p: [
        "d ${p} 2770 ${owner} gamers -"
        "a+ ${p} - - - - ${acl}"
      ];
    in
    lib.concatMap (mkRules "root") cfg.game_lib_dirs
    ++ lib.optional (cfg.shared_steam_dir != null)
        "d ${cfg.shared_steam_dir} 0700 root root -";

    services.udev.extraRules = ''
      ACTION=="add|change", SUBSYSTEM=="block", ATTR{queue/scheduler}="bfq"
    '';

    # Enable VK basalt compatibility
    system.activationScripts.vkbasalt-compat = ''
      mkdir -p /usr/share/vulkan/implicit_layer.d
      ln -sf /run/current-system/sw/share/vulkan/implicit_layer.d/vkBasalt.json /usr/share/vulkan/implicit_layer.d/vkBasalt.json

      mkdir -p /usr/lib
      if [ -f "${pkgs-unstable.vkbasalt}/lib/libvkbasalt.so" ]; then
        ln -sf "${pkgs-unstable.vkbasalt}/lib/libvkbasalt.so" /usr/lib/libvkbasalt.so
      fi
    '';

    boot = {
      kernelPackages = pkgs.linuxPackages_zen;
      tmp.cleanOnBoot = lib.mkMxDefault true;
      kernel.sysctl = {
        "kernel.split_lock_mitigate" = lib.mkMxDefault 0;
        "vm.vfs_cache_pressure" = lib.mkMxDefault 50;
        "vm.dirty_bytes" = lib.mkMxDefault 268435456;
        "vm.max_map_count" = lib.mkMxDefault 16777216;
        "vm.dirty_background_bytes" = lib.mkMxDefault 67108864;
        "vm.dirty_writeback_centisecs" = lib.mkMxDefault 1500;
        "kernel.nmi_watchdog" = lib.mkMxDefault 0;
        "kernel.unprivileged_userns_clone" = lib.mkMxDefault 1;
        "kernel.printk" = lib.mkMxDefault "3 3 3 3";
        "kernel.kptr_restrict" = lib.mkMxDefault 2;
        "kernel.kexec_load_disabled" = lib.mkMxDefault 1;
      };
    };

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        var allowedUnits = ${builtins.toJSON gameServices.enabledUnits};

        if (action.id === "org.freedesktop.systemd1.manage-units" &&
            subject.isInGroup("wheel") &&
            allowedUnits.indexOf(action.lookup("unit")) !== -1) {
          return polkit.Result.YES;
        }

        if (action.id === "org.freedesktop.UPower.PowerProfiles.switch-profile" &&
            subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
