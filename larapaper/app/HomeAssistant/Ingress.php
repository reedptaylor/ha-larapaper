<?php

namespace App\HomeAssistant;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\URL;
use Symfony\Component\HttpFoundation\Response;

/**
 * Serves LaraPaper under Home Assistant's ingress path (/api/hassio_ingress/<token>).
 */
class Ingress
{
    // The Supervisor's ingress proxy. Every other app on the Supervisor network has a 172.30.33.x address.
    private const PROXY_IP = '172.30.32.2';

    /**
     * Whether the request came through ingress. Checks the socket address rather than $request->ip(),
     * which TRUSTED_PROXIES resolves to the browser's address from X-Forwarded-For. That relies on
     * nginx's TRUSTED_PROXY=off (config.yaml): its other modes rewrite REMOTE_ADDR from client headers.
     * (Don't reject CF-Connecting-IP here: HA passes it through when it's behind Cloudflare.)
     */
    public static function from(Request $request): bool
    {
        return $request->server('REMOTE_ADDR') === self::PROXY_IP && $request->headers->has('X-Ingress-Path');
    }

    public function handle(Request $request, Closure $next): Response
    {
        if (! self::from($request)) {
            return $next($request);
        }

        $prefix = rtrim($request->header('X-Ingress-Path'), '/');

        // Laravel trusts X-Forwarded-Prefix from TRUSTED_PROXIES, so generated URLs, redirects and
        // signed-URL checks (e.g. Livewire uploads) all include the ingress path.
        $request->headers->set('X-Forwarded-Prefix', $prefix);

        // Drop the root URL cached while booting, before the prefix was set.
        URL::setRequest($request);

        // AppServiceProvider sets the public disk URL while booting, too.
        config(['filesystems.disks.public.url' => $prefix.'/storage']);
        Storage::forgetDisk('public');

        return $next($request);
    }
}
