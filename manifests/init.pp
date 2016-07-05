# Class: rocket_chat
# ===========================
#
# Full description of class rocket_chat here.
#
# Parameters
# ----------
#
# Document parameters here.
#
# * `sample parameter`
# Explanation of what this parameter affects and what it defaults to.
# e.g. "Specify one or more upstream ntp servers as an array."
#
# Variables
# ----------
#
# Here you should define a list of variables that this module would require.
#
# * `version`
#  Explanation of how this variable affects the function of this class and if
#  it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#  External Node Classifier as a comma separated list of hostnames." (Note,
#  global variables should be avoided in favor of class parameters as
#  of Puppet 2.6.)
#
# Examples
# --------
#
# @example
#    class { 'rocket_chat':
#      version => '0.34.0',
#    }
#
# Authors
# -------
#
# Author Name <bryan@bryanskitchen.net>
#
# Copyright
# ---------
#
# Copyright 2016 Bryan Wood, unless otherwise noted.
#
# DOCS: https://rocket.chat/docs/installation/manual-installation/centos/
class rocket_chat (
  $version          = 'latest',
  $download_url     = "https://rocket.chat/releases/${version}/download",
  $cleanup          = true,
  $install_location = '/opt/rocket.chat',
  $public_dns       = $fqdn,
  $port             = '80',
){
  include archive
  include nodejs
  require epel

  class { 'selinux':
    mode => 'disabled',
  }

  $packages = ['GraphicsMagick', 'mongodb-org-server', 'mongodb-org']
  $npm_packages = ['inherits', 'n']

  #Install system packages
  package { $packages:
    ensure  => present,
    require => Yumrepo['mongodb'],
  }


  package { $npm_packages:
    ensure   => present,
    provider => 'npm',
    require  => Package[$packages],
  }

  yumrepo { 'mongodb':
    ensure   => 'present',
    baseurl  => 'http://downloads-distro.mongodb.org/repo/redhat/os/x86_64/',
    descr    => 'MongoDB Repository',
    enabled  => '1',
    gpgcheck => '0',
  }

  file { $install_location:
    ensure  => directory,
    owner   => root,
    group   => root,
    mode    => '0755',
    require => Class['selinux'],
  }

  #Meteor needs Node.js version 0.10.40 using n we are going to install that version
  exec {'Install Node.js version 0.10.40':
    command => 'n 0.10.40',
    creates => '/usr/local/n/versions/node/0.10.40',
    path    => '/bin',
    require => [Package[$packages],Package[$npm_packages]],
  }

  archive { "/tmp/rocket.chat-${version}.tgz":
    ensure          => present,
    extract         => true,
    extract_path    => '/opt/rocket.chat',
    extract_command => 'tar xfz %s --strip-components=1',
    source          => $download_url,
    creates         => "${install_location}/main.js",
    cleanup         => $cleanup,
    require         => [File['/opt/rocket.chat'], Exec['Install Node.js version 0.10.40']],
    notify          => Exec['npm install'],
  }

  exec {'npm install':
    command     => "cd ${install_location}/programs/server && npm install",
    refreshonly => true,
    path        => '/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/puppetlabs/bin:/root/bin',

  }

  file {'/usr/lib/systemd/system/rocketchat.service':
    owner   => root,
    group   => root,
    mode    => '0644',
    content => template('rocket_chat/rocketchat.service.erb'),
  }

  service { 'rocketchat':
    ensure  => running,
    enable  => true,
    subscribe => File['/usr/lib/systemd/system/rocketchat.service'],
    require => [File['/usr/lib/systemd/system/rocketchat.service'],Exec['npm install']],
  }

}
