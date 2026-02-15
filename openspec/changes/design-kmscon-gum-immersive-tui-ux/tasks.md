# Tasks: Immersive TUI & KMSCON

- [ ] **Infrastructure: KMSCON** <!-- id: 1 -->
    - [ ] Add `kmscon` and Nerd Fonts to `tools.list.chroot` <!-- id: 1.1 -->
    - [ ] Create `/etc/kmscon/kmscon.conf` with font and term settings <!-- id: 1.2 -->
    - [ ] Configure systemd override to replace `getty@tty1` with `kmscon` <!-- id: 1.3 -->

- [ ] **Foundation: Gum Wrapper Library** <!-- id: 2 -->
    - [ ] Create `libs/ui-gum.sh` <!-- id: 2.1 -->
        - [ ] Implement `sys_gum_wrapper` (env vars, checks) <!-- id: 2.1.1 -->
        - [ ] Implement `sys_header` (double border, project branding) <!-- id: 2.1.2 -->
        - [ ] Implement `sys_page` (vertical join, full height calculation) <!-- id: 2.1.3 -->
        - [ ] Implement `sys_select_filter` (icons, search) <!-- id: 2.1.4 -->
        - [ ] Implement `sys_input` (validation, placeholders) <!-- id: 2.1.5 -->
        - [ ] Implement `sys_confirm` (yes/no, default no) <!-- id: 2.1.6 -->

- [ ] **Implementation: Installer Steps Refactor** <!-- id: 3 -->
    - [ ] Refactor `00-welcome.sh` to use `ui-gum.sh` (Pilot) <!-- id: 3.1 -->
    - [ ] Refactor `01-select-disk.sh` <!-- id: 3.2 -->
    - [ ] Refactor `02-configure-zfs.sh` <!-- id: 3.3 -->
    - [ ] Refactor remaining steps <!-- id: 3.4 -->

- [ ] **Verification** <!-- id: 4 -->
    - [ ] Build ISO and verify package installation <!-- id: 4.1 -->
    - [ ] Boot VM and verify KMSCON launch <!-- id: 4.2 -->
    - [ ] Validate TUI layout (borders, colors, input) <!-- id: 4.3 -->
