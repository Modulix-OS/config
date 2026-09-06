# Test VMs

Throwaway QEMU VMs to test the `mx.desktop` option end-to-end.

| Config        | `mx.desktop` | Expect                          |
|---------------|--------------|---------------------------------|
| `test-gnome`  | `gnome`      | GDM + GNOME, Modulix logo on the greeter |
| `test-plasma` | `plasma`     | SDDM (Wayland) + Plasma 6, Modulix menu logo |
| `test-cli`    | `cli`        | no DE, getty autologin          |

User `mainuser` / password `1234` (autologin enabled).

## Run

```sh
cd test
nix build .#nixosConfigurations.test-plasma.config.system.build.vm
./result/bin/run-mx-test-plasma-vm
```

Swap `test-plasma` for `test-gnome` / `test-cli`.

Quit the VM: close the window or `Ctrl-A X` in the terminal. State lives in
`*.qcow2` next to where you launched it — delete to reset.

## Notes
- Imports the parent module tree via `../modules`; pins the same inputs as the
  root flake (nixpkgs 25.11, nix-cachyos-kernel for the always-applied kernel overlay).
- Limine bootloader disabled (`mx.bootloader.enable = false`) — qemu-vm boots it.
- The Modulix logo (`pkgs/modulix-logo.nix`, built from `assets/modulix-logo.png`)
  is installed system wide by `mx.branding` — it feeds the Plasma menu, the GDM
  greeter and `LOGO=` in `/etc/os-release`.
