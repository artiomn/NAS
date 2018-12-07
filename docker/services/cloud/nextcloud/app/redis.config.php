<?php
$CONFIG = array (
 'memcache.local' => '\OC\Memcache\APCu',
 'memcache.locking' => '\OC\Memcache\Redis',
 'memcache.distributed' => '\OC\Memcache\Redis',
  'redis' => array(
    'host' => 'redis',
    'port' => 6379,
  ),
);

