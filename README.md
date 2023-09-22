# ferut

Fedora Ruby packaging Tools (ferut) is set of tools to help with packagin of
Ruby on Fedora. These tools are very utilitarian and there is no guarantee they
will work for you.

## ruby-devel-srpm.rb

Prepare development snapshot using mock tool and adjust a few bits in the
ruby.spec file, such as revision and versions of bundled packages.

## ruby-patches.sh

Fix Ruby patches to apply cleanly.

## rename-patch.sh

Renames specified patch in a way `git format-patch` would do, extracting
required information from `Subject:` line.

The whole idea was discussed [here](https://lore.kernel.org/git/xmqqo7inw2na.fsf@gitster.g/T/#m89274225998784c705d4a8ff647dfd0b3c58f682)
and Git might provide some better plumbing for this tool.
