FROM ghcr.io/usetrmnl/larapaper:0.45.0

# Run as root so the startup script can own /config; serversideup's
# 5-fpm-pool-user.sh then drops PHP-FPM workers back to www-data.
USER root

COPY --chmod=755 20-ha-persist.sh /etc/entrypoint.d/20-ha-persist.sh
