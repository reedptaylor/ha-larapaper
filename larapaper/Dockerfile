FROM ghcr.io/usetrmnl/larapaper:0.45.1

# Run as root so the startup script can own /config; serversideup's
# 5-fpm-pool-user.sh then drops PHP-FPM workers back to www-data.
USER root

COPY --chmod=755 20-ha-persist.sh /etc/entrypoint.d/20-ha-persist.sh

# Ingress sidebar support: see app/HomeAssistant.
COPY --chown=www-data:www-data app/HomeAssistant /var/www/html/app/HomeAssistant
COPY --chown=www-data:www-data config/homeassistant.php /var/www/html/config/homeassistant.php
# Register the provider. Fails the build if upstream's providers list no longer ends in "];".
RUN php -r '$f = "/var/www/html/bootstrap/providers.php"; \
    $s = str_replace("];", "    App\\HomeAssistant\\HomeAssistantServiceProvider::class,\n];", file_get_contents($f), $n); \
    $n === 1 || exit(1); file_put_contents($f, $s);'
