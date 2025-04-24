# State file to upgrade Ubuntu 18.04 to 20.04 and then to 22.04 non-interactively
# Uses centralized repository, checks reboot requirement, verifies and removes lxd package
# Reboots after dist-upgrade if required, reboots after each upgrade, waits for server to come back online, and confirms 22.04 upgrade

# Check if a reboot is required
check_reboot_required:
  cmd.run:
    - name: '[ -f /var/run/reboot-required ] && echo "Reboot required" && exit 1 || echo "No reboot required"'
    - shell: /bin/bash
    - unless: '[ ! -f /var/run/reboot-required ]'

# Ensure lxd package is not installed
remove_lxd:
  pkg.removed:
    - name: lxd
    - onlyif: dpkg -l | grep -q lxd
    - require:
      - cmd: check_reboot_required

# Ensure snapd is removed (lxd dependency)
remove_snapd:
  pkg.removed:
    - name: snapd
    - onlyif: dpkg -l | grep -q snapd
    - require:
      - pkg: remove_lxd

# Clean up any residual lxd files
cleanup_lxd_residuals:
  cmd.run:
    - name: 'rm -rf /var/lib/lxd /var/snap/lxd'
    - onlyif: 'test -d /var/lib/lxd || test -d /var/snap/lxd'
    - require:
      - pkg: remove_lxd
      - pkg: remove_snapd

# Configure apt sources for Ubuntu 20.04 using centralized repository
update_sources_list_20_04:
  file.managed:
    - name: /etc/apt/sources.list
    - contents: |
        deb http://10.13.0.88/ubuntu focal main universe
        deb http://10.13.0.88/ubuntu focal-updates main universe
        deb http://10.13.0.88/ubuntu focal-security main universe
        deb http://10.13.0.88/ubuntu focal-backports main universe
    - require:
      - cmd: cleanup_lxd_residuals

# Update package cache and perform dist-upgrade for 20.04
update_apt_cache_20_04:
  cmd.run:
    - name: 'apt-get update && apt-get dist-upgrade -y'
    - env:
        - DEBIAN_FRONTEND: noninteractive
    - require:
      - file: update_sources_list_20_04

# Check if reboot is required after dist-upgrade for 20.04
check_reboot_after_dist_upgrade_20_04:
  cmd.run:
    - name: '[ -f /var/run/reboot-required ] && echo "Reboot required after dist-upgrade" || echo "No reboot required"'
    - shell: /bin/bash
    - require:
      - cmd: update_apt_cache_20_04

# Reboot if required after dist-upgrade for 20.04
reboot_after_dist_upgrade_20_04:
  cmd.run:
    - name: 'reboot'
    - shell: /bin/bash
    - onlyif: '[ -f /var/run/reboot-required ]'
    - require:
      - cmd: check_reboot_after_dist_upgrade_20_04

# Wait for Salt minion to come back online after dist-upgrade reboot for 20.04
wait_for_reboot_after_dist_upgrade_20_04:
  cmd.run:
    - name: |
        for i in {1..30}; do
          if salt-call test.ping; then
            exit 0
          fi
          sleep 10
        done
        echo "Timeout waiting for Salt minion" && exit 1
    - shell: /bin/bash
    - require:
      - cmd: reboot_after_dist_upgrade_20_04

# Install update-manager-core for 20.04
install_update_manager_20_04:
  pkg.installed:
    - name: update-manager-core
    - require:
      - cmd: update_apt_cache_20_04
      - cmd: wait_for_reboot_after_dist_upgrade_20_04

# Perform the distribution upgrade to 20.04 non-interactively
do_release_upgrade_20_04:
  cmd.run:
    - name: 'do-release-upgrade -m server -f DistUpgradeViewNonInteractive'
    - env:
        - DEBIAN_FRONTEND: noninteractive
    - require:
      - pkg: install_update_manager_20_04

# Reboot after 20.04 upgrade
reboot_after_20_04:
  cmd.run:
    - name: 'reboot'
    - shell: /bin/bash
    - require:
      - cmd: do_release_upgrade_20_04

# Wait for Salt minion to come back online
wait_for_reboot_20_04:
  cmd.run:
    - name: |
        for i in {1..30}; do
          if salt-call test.ping; then
            exit 0
          fi
          sleep 10
        done
        echo "Timeout waiting for Salt minion" && exit 1
    - shell: /bin/bash
    - require:
      - cmd: reboot_after_20_04

# Configure apt sources for Ubuntu 22.04
update_sources_list_22_04:
  file.managed:
    - name: /etc/apt/sources.list
    - contents: |
        deb http://10.13.0.88/ubuntu jammy main universe
        deb http://10.13.0.88/ubuntu jammy-updates main universe
        deb http://10.13.0.88/ubuntu jammy-security main universe
        deb http://10.13.0.88/ubuntu jammy-backports main universe
    - require:
      - cmd: wait_for_reboot_20_04

# Update package cache and perform dist-upgrade for 22.04
update_apt_cache_22_04:
  cmd.run:
    - name: 'apt-get update && apt-get dist-upgrade -y'
    - env:
        - DEBIAN_FRONTEND: noninteractive
    - require:
      - file: update_sources_list_22_04

# Check if reboot is required after dist-upgrade for 22.04
check_reboot_after_dist_upgrade_22_04:
  cmd.run:
    - name: '[ -f /var/run/reboot-required ] && echo "Reboot required after dist-upgrade" || echo "No reboot required"'
    - shell: /bin/bash
    - require:
      - cmd: update_apt_cache_22_04

# Reboot if required after dist-upgrade for 22.04
reboot_after_dist_upgrade_22_04:
  cmd.run:
    - name: 'reboot'
    - shell: /bin/bash
    - onlyif: '[ -f /var/run/reboot-required ]'
    - require:
      - cmd: check_reboot_after_dist_upgrade_22_04

# Wait for Salt minion to come back online after dist-upgrade reboot for 22.04
wait_for_reboot_after_dist_upgrade_22_04:
  cmd.run:
    - name: |
        for i in {1..30}; do
          if salt-call test.ping; then
            exit 0
          fi
          sleep 10
        done
        echo "Timeout waiting for Salt minion" && exit 1
    - shell: /bin/bash
    - require:
      - cmd: reboot_after_dist_upgrade_22_04

# Install update-manager-core for 22.04
install_update_manager_22_04:
  pkg.installed:
    - name: update-manager-core
    - require:
      - cmd: update_apt_cache_22_04
      - cmd: wait_for_reboot_after_dist_upgrade_22_04

# Perform the distribution upgrade to 22.04 non-interactively
do_release_upgrade_22_04:
  cmd.run:
    - name: 'do-release-upgrade -m server -f DistUpgradeViewNonInteractive'
    - env:
        - DEBIAN_FRONTEND: noninteractive
    - require:
      - pkg: install_update_manager_22_04

# Reboot after 22.04 upgrade
reboot_after_22_04:
  cmd.run:
    - name: 'reboot'
    - shell: /bin/bash
    - require:
      - cmd: do_release_upgrade_22_04

# Wait for Salt minion to come back online
wait_for_reboot_22_04:
  cmd.run:
    - name: |
        for i in {1..30}; do
          if salt-call test.ping; then
            exit 0
          fi
          sleep 10
        done
        echo "Timeout waiting for Salt minion" && exit 1
    - shell: /bin/bash
    - require:
      - cmd: reboot_after_22_04

# Confirm Ubuntu 22.04 upgrade
confirm_22_04_upgrade:
  cmd.run:
    - name: |
        salt-call saltutil.refresh_grains
        if lsb_release -a 2>/dev/null | grep -q "22.04"; then
          echo "Ubuntu 22.04 upgrade successful"
          exit 0
        else
          echo "Ubuntu 22.04 upgrade failed"
          exit 1
        fi
    - shell: /bin/bash
    - require:
      - cmd: wait_for_reboot_22_04
