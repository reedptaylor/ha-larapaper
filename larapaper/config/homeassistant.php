<?php

// Set from the app's options by 20-ha-persist.sh.
return [
    'ingress_login' => env('HA_INGRESS_LOGIN') ?: null,
    'ingress_ha_user' => env('HA_INGRESS_HA_USER') ?: null,
];
