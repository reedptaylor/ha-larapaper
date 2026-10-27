<?php

namespace App\HomeAssistant;

use Illuminate\Contracts\Auth\Middleware\AuthenticatesRequests;
use Illuminate\Contracts\Http\Kernel;
use Illuminate\Support\ServiceProvider;

class HomeAssistantServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        $kernel = $this->app->make(Kernel::class);

        // Global, after TrustProxies, so the prefix is in place before routing.
        $kernel->pushMiddleware(Ingress::class);

        // Through the kernel, not the router: the kernel re-syncs its groups over the router's.
        $kernel->appendMiddlewareToGroup('web', IngressLogin::class);

        // After StartSession, and before the auth middleware can redirect to the login page.
        $kernel->addToMiddlewarePriorityBefore(AuthenticatesRequests::class, IngressLogin::class);
    }
}
