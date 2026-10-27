<?php

namespace App\HomeAssistant;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

/**
 * Logs ingress requests into the LaraPaper account set in the app's options, since Home Assistant
 * has already authenticated the user.
 */
class IngressLogin
{
    public function handle(Request $request, Closure $next): Response
    {
        $email = config('homeassistant.ingress_login');
        $haUser = config('homeassistant.ingress_ha_user');

        // The Supervisor strips any X-Remote-User-* headers the browser sends and sets its own.
        if ($email && ! Auth::check() && Ingress::from($request)
            && (! $haUser || $request->header('X-Remote-User-Name') === $haUser)) {
            if ($user = User::firstWhere('email', $email)) {
                Auth::login($user);
                $request->session()->regenerate();
            } else {
                Log::warning("ingress_login: no LaraPaper user with email {$email}");
            }
        }

        return $next($request);
    }
}
