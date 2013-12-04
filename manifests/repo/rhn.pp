# This define creates and manages a redhat mrepo repository.
#
# == Parameters
#
# [*rhn*]
# Whether to generate rhn metadata for these repos.
# Default: false
#
# [*rhnrelease*]
# The name of the RHN release as understood by mrepo. Optional.
#
# == Examples
#
# TODO
#
# Further examples can be found in the module README.
#
# == Author
#
# Adrien Thebo <adrien@puppetlabs.com>
#
# == Copyright
#
# Copyright 2012 Puppet Labs, unless otherwise noted
#
define mrepo::repo::rhn (
  $ensure,
  $release,
  $arch,
  $urls       = {},
  $metadata   = 'repomd',
  $update     = 'nightly',
  $hour       = '0',
  $iso        = '',
  $typerelease = $release,
  $repotitle  = $name
) {
  include mrepo::params

  $http_proxy   = $mrepo::params::http_proxy
  $https_proxy  = $mrepo::params::https_proxy

  if ( $http_proxy ) {
    $http_proxy_array = ["http_proxy=${http_proxy}"]
  }
  else {
    $http_proxy_array = []
  }
  if ( $https_proxy ) {
    $https_proxy_array = ["https_proxy=${https_proxy}"]
  }
  else {
    $https_proxy_array = []
  }

  $environment  = concat($http_proxy_array,$https_proxy_array)

  case $ensure {
    present: {
      exec { "Generate systemid $name - $arch":
        command   => "gensystemid -u '${mrepo::params::rhn_username}' -p '${mrepo::params::rhn_password}' --release '${typerelease}' --arch '${arch}' '${mrepo::params::src_root}/${name}'",
        path      => [ "/bin", "/usr/bin" ],
        user      => $mrepo::params::user,
        group     => $mrepo::params::group,
        creates   => "${mrepo::params::src_root}/${name}/systemid",
        require   => [
          Class['mrepo::package'],
          Class['mrepo::rhn'],
        ],
        before      => Exec["Generate mrepo repo ${name}"],
        logoutput   => on_failure,
        environment => $environment,
      }
    }
  }
}
