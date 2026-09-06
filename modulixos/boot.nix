{ pkgs, lib, config, ... }:

let
  cfg = config.mx.bootloader;
  splashBackground = ../assets/bootloader-background.png;
  logo = ../assets/modulix-logo.png;
  plymouthTheme = pkgs.callPackage ../pkgs/modulix-plymouth-theme.nix {
    watermarkVerticalAlignment = cfg.splash.logoPosition;
  };
in
{
  options.mx.bootloader = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use default bootloader";
    };
    secureBoot.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable secure boot";
    };
    splash = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Show the Modulix branding across the boot: Limine background image,
          then the Plymouth screen, where the default `bgrt` theme keeps the
          firmware vendor logo and draws the Modulix logo as a watermark.
        '';
      };
      image = lib.mkOption {
        type = lib.types.path;
        default = splashBackground;
        description = "Bootloader background image (PNG).";
      };
      logo = lib.mkOption {
        type = lib.types.path;
        default = logo;
        defaultText = lib.literalExpression ''"''${pkgs.modulix-boot-splash}/share/modulix/logo.png"'';
        description = "Modulix logo drawn as the Plymouth watermark (PNG).";
      };
      logoPosition = lib.mkOption {
        type = lib.types.float;
        default = 0.9;
        description = ''
          Vertical position of the Modulix watermark on the Plymouth screen,
          from 0.0 (top) to 1.0 (bottom). Plymouth places the image at
          `logoPosition * (screenHeight - logoHeight)`, so the value is
          resolution independent. The upstream `bgrt` theme uses 0.96.
        '';
      };
    };
  };
  config = lib.mkMerge [
    (
      lib.mkIf cfg.enable {
        boot.loader.limine = {
          enable = true;
          maxGenerations = lib.mkMxDefault 10;
          secureBoot = {
            enable = cfg.secureBoot.enable;
            autoGenerateKeys = lib.mkMxDefault cfg.secureBoot.enable;
            autoEnrollKeys = {
              enable = cfg.secureBoot.enable;
              extraArgs = [
                "--microsoft"
                "--firmware-builtin"
              ];
            };
          };

          extraConfig = ''
            quiet: yes
            remember_last_entry: no
          '';
          style = lib.mkIf cfg.splash.enable {
            wallpapers = [ cfg.splash.image ];
            wallpaperStyle = lib.mkMxDefault "stretched";
            interface = {
              branding = lib.mkMxDefault "ModulixOS";
              helpHidden = lib.mkMxDefault true;
            };
          };
        };

        boot.loader.timeout = lib.mkMxDefault 1;
        boot.loader.efi.canTouchEfiVariables = lib.mkMxDefault true;
      }
    )
    {
      boot = {
        kernelPackages = lib.mkDefault pkgs.linuxPackages;
        initrd.verbose = lib.mkMxDefault false;
        tmp.useTmpfs = lib.mkMxDefault true;

        kernelParams = [
          "quiet"
          "udev.log_level=3"
          "rd.udev.log_level=3"
          "systemd.show_status=false"
          "rd.systemd.show_status=false"
          "vt.global_cursor_default=0"
          "iommu=pt" # Fix pour certain cpu AMD
        ];
        consoleLogLevel = lib.mkMxDefault 3;

        initrd.systemd.enable = lib.mkDefault true;
        plymouth = {
          enable = lib.mkMxDefault (!config.mx.mode.server.enable);
          logo = lib.mkIf cfg.splash.enable (lib.mkMxDefault cfg.splash.logo);
          theme = lib.mkIf cfg.splash.enable (lib.mkMxDefault "modulix");
          themePackages = lib.mkIf cfg.splash.enable [ plymouthTheme ];
        };

        initrd.systemd.tpm2.enable = true;
        initrd.systemd.services.systemd-udev-settle.enable = lib.mkForce false;
      };

      # Fastest boot
      systemd.network.wait-online.enable = false;
      systemd.services.systemd-udev-settle.enable = lib.mkForce false;
    }
  ];
}
