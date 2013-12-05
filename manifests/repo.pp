# This define creates and manages an mrepo repository. It generates an mrepo
# repository file definition and will generate the initial repository. If the
# update parameter is set to "now", the repository will be immediately
# synchronized.
#
# == Parameters
#
# [*ensure*]
# Creates or destroys the given repository
# Values: present,absent
#
# [*release*]
# The distribution release to mirror
#
# [*arch*]
# The architecture of the release to mirror.
# Values: i386, i586, x86_64, ppc, s390, s390x, ia64
#
#
# [*urls*]
# A hash of repository names and URLs.
#
# [*metadata*]
# The metadata type for the repository. More than one value can be used in
# an array.
# Default: repomd
# Values: yum,apt,repomd
#
# [*update*]
# The schedule for updating.The 'now' will update the repo on every run of 
# puppet. Be warned that this could be a very lengthy process on the first run.
# Default: nightly
# Values: now, nightly, weekly, never
#
# [*hour*]
# The hour to run the sync. Optional.
# Default: 0
#
# [*iso*]
# The pattern of the ISO to mirror. Optional.
#
# [*rhn*]
# Whether to generate rhn metadata for these repos.
# Default: false
#
# [*rhnrelease*]
# The name of the RHN release as understood by mrepo.
# Default: $release
#
# [*repotitle*]
# The human readable title of the repository.
# Default: $name
#
# [*gen_timeout*]
# The number of seconds to allow mrepo to generate the initial repository.
# Default: 1200
#
# [*sync_timeout*]
# The number of seconds to allow mrepo to sync a repository.
# Default: 3600
#
# [*mrepo_options*]
# Options passed to the mrepo command
# Default: -qgu (Quiet, Generate, Update)
#
# [*mrepo_logging*]
# Can be used to redirect output to a logfile for later inspection
# Default: empty
#
# == Examples
#
# mrepo::repo { "centos5-x86_64":
#   ensure    => present,
#   arch      => "x86_64",
#   release   => "5.5",
#   repotitle => "CentOS 5.5 64 bit",
#   urls      => {
#     addons      => "http://mirrors.kernel.org/centos/5.6/addons/x86_64/",
#     centosplus  => "http://mirrors.kernel.org/centos/5.6/centosplus/x86_64/",
#     contrib     => "http://mirrors.kernel.org/centos/5.6/contrib/x86_64/",
#     extras      => "http://mirrors.kernel.org/centos/5.6/extras/x86_64/",
#     fasttrack   => "http://mirrors.kernel.org/centos/5.6/fasttrack/x86_64/",
#     updates     => "http://mirrors.kernel.org/centos/5.6/updates/x86_64/",
#   }
# }
#
# Further examples can be found in the module README.
#
# == See Also
#
# mrepo usage: https://github.com/dagwieers/mrepo/blob/master/docs/usage.txt
#
# For rhn mirroring, see README.redhat.markdown
#
# == Author
#
# Adrien Thebo <adrien@puppetlabs.com>
#
# == Copyright
#
# Copyright 2011 Puppet Labs, unless otherwise noted
#
define mrepo::repo (
  $ensure,
  $release,
  $arch,
  $urls          = {},
  $metadata      = 'repomd',
  $update        = 'nightly',
  $hour          = '0',
  $minute        = '0',
  $iso           = '',
  $repotitle     = $name,
  $gen_timeout   = '1200',
  $sync_timeout  = '1200',
  $type          = 'std',
  $typerelease   = undef,
  $mrepo_env     = '',
  $mrepo_command = '/usr/bin/mrepo',
  $mrepo_options = '-qgu',
  $mrepo_logging = '',
  $createrepo_options = '',
) {
  include mrepo
  include mrepo::params

  validate_re($ensure, "^present$|^absent$")
  validate_re($arch, "^i386$|^i586$|^x86_64$|^ppc$|^s390$|^s390x$|^ia64$")
  validate_re($update, "^now$|^nightly$|^weekly$|^never$")
  validate_re($type  , "^std$|^ncc$|^rhn$")

  # mrepo tries to be clever, and if the arch is the suffix of the name will
  # fold the two, but if the name isn't x86_64 or i386, no folding occurs.
  # This manages the inconsistent behavior.
  $real_name = mrepo_munge($name, $arch)

  $www_root_subdir = "${mrepo::params::www_root}/${real_name}"
  $src_root_subdir = "${mrepo::params::src_root}/${real_name}"

  case $ensure {
    present: {

      $user  = $mrepo::params::user
      $group = $mrepo::params::group

      file { "/etc/mrepo.conf.d/$name.conf":
        ensure  => present,
        owner   => $user,
        group   => $group,
        content => template("mrepo/repo.conf.erb"),
        require => Class['mrepo::package'],
      }

      file { $src_root_subdir:
        ensure  => directory,
        owner   => $user,
        group   => $group,
        mode    => "0755",
        backup  => false,
        recurse => false,
      }

      exec { "Generate mrepo repo $name":
        command   => "mrepo -g $name",
        cwd       => $src_root,
        path      => [ "/usr/bin", "/bin" ],
        user      => $user,
        group     => $group,
        creates   => $www_root_subdir,
        timeout   => $gen_timeout,
        require   => Class['mrepo::package'],
        subscribe => File["/etc/mrepo.conf.d/$name.conf"],
        logoutput => on_failure,
      }

      $repo_command = "${mrepo_env} ${mrepo_command} ${mrepo_options} ${name} ${mrepo_logging}"
      case $update {
        now: {
          exec { "Synchronize repo $name":
            command   => $repo_command,
            cwd       => $src_root,
            path      => [ "/usr/bin", "/bin" ],
            user      => $user,
            group     => $group,
            timeout   => $sync_timeout,
            require   => Class['mrepo::package'],
            logoutput => on_failure,
          }
          cron {
            "Nightly synchronize repo $name":
              ensure  => absent;
            "Weekly synchronize repo $name":
              ensure  => absent;
          }
        }
        nightly: {
          cron {
            "Nightly synchronize repo $name":
              ensure  => present,
              command   => $repo_command,
              hour    => $hour,
              minute  => $minute,
              user    => $user,
              require => Class['mrepo::package'];
            "Weekly synchronize repo $name":
              ensure  => absent;
          }
        }
        weekly: {
          cron {
            "Weekly synchronize repo $name":
              ensure  => present,
              command   => $repo_command,
              weekday => "0",
              hour    => $hour,
              minute  => $minute,
              user    => $user,
              require => Class['mrepo::package'];
            "Nightly synchronize repo $name":
              ensure  => absent;
          }
        }
      }
     
      if $type != 'std' {
        #notify { "Type = ${type}": }
        create_resources( "mrepo::repo::${type}",
          { "$name"      => {
              ensure     => $ensure,
              release    => $release,
              arch       => $arch,
              repotitle  => $repotitle,
              typerelease => $typerelease,
            }
          }
        )
      }

    }
    absent: {
      exec { "Unmount any mirrored ISOs for ${name}":
        command   => "umount ${www_root_subdir}/disc*",
        path      => ["/usr/bin", "/bin", "/usr/sbin", "/sbin"],
        onlyif    => "mount | grep ${www_root_subdir}/disk",
        provider  => shell,
        logoutput => true,
      }
      file {
        $www_root_subdir:
          ensure  => absent,
          backup  => false,
          recurse => false,
          force   => true,
          before  => File[$src_root_subdir],
          require => Exec["Unmount any mirrored ISOs for ${name}"];
        "${mrepo::params::src_root}/$name":
          ensure  => absent,
          backup  => false,
          recurse => false,
          force   => true;
        "/etc/mrepo.conf.d/$name":
          ensure  => absent,
          backup  => false,
          force   => true;
      }
      cron {
        "Nightly synchronize repo $name":
          ensure  => absent;
        "Weekly synchronize repo $name":
          ensure  => absent;
      }
    }
  }
}
