<?php

namespace App\Filters;

use App\Libraries\Sync_lib;
use App\Models\Employee;
use CodeIgniter\Filters\FilterInterface;
use CodeIgniter\HTTP\Exceptions\RedirectException;
use CodeIgniter\HTTP\RequestInterface;
use CodeIgniter\HTTP\ResponseInterface;
use Config\Sync;

class IsLoggedIn implements FilterInterface
{
    public function before(RequestInterface $request, $arguments = null)
    {
        $employee = model(Employee::class);

        if (!$employee->is_logged_in()) {
            throw new RedirectException('login');
        }

        $session = session();
        $lastActivity = (int) $session->get('last_activity');
        if ($lastActivity > 0 && time() - $lastActivity > config(Sync::class)->idleMinutes * 60) {
            (new Sync_lib())->endSession('idle');
            $employee->logout();

            throw new RedirectException('login?idle=1');
        }
        if (!str_ends_with($request->getUri()->getPath(), 'sync/heartbeat')) {
            $session->set('last_activity', time());
        }
    }

    public function after(RequestInterface $request, ResponseInterface $response, $arguments = null)
    {
    }
}
