<?php

namespace App\Controllers;

use App\Libraries\Sync_lib;
use CodeIgniter\HTTP\ResponseInterface;
use Throwable;

/**
 * Multi-site sync actions used by the status bar (app/Views/partial/sync_bar.php) and Configuration > Sync.
 */
class Sync extends Secure_Controller
{
    private Sync_lib $sync;

    public function __construct()
    {
        parent::__construct();
        $this->sync = new Sync_lib();
    }

    public function getStatus(): ResponseInterface
    {
        return $this->response->setJSON($this->sync->status(true));
    }

    /**
     * Keeps the offline-mode lock alive while a user is active. Not counted as activity (see IsLoggedIn).
     */
    public function postHeartbeat(): ResponseInterface
    {
        try {
            $alive = $this->sync->heartbeat();
        } catch (Throwable $e) {
            $alive = true;    // the online database being unreachable is not a lost lock
        }

        return $this->response->setJSON(['lock' => $alive] + $this->sync->status(false));
    }

    public function postPush(): ResponseInterface
    {
        if (!$this->sync->isOffline()) {
            return $this->fail(lang('Sync.mode_online'));
        }
        if (!$this->sync->holdsLockLocally()) {
            return $this->fail(lang('Sync.not_holder'));
        }

        try {
            $result = $this->sync->push('manual');
        } catch (Throwable $e) {
            return $this->fail($e->getMessage());
        }

        return $this->response->setJSON(['success' => true, 'message' => lang('Sync.push_done', [$result['tables'], $result['files']])]);
    }

    public function postPull(): ResponseInterface
    {
        if (!$this->sync->isOffline()) {
            return $this->fail(lang('Sync.mode_online'));
        }

        try {
            $result = $this->sync->pull('manual');
        } catch (Throwable $e) {
            return $this->fail($e->getMessage());
        }

        return $this->response->setJSON(['success' => true, 'message' => lang('Sync.pull_done', [$result['tables'], $result['files']])]);
    }

    public function postTakeOver(): ResponseInterface
    {
        $user = $this->employee->get_logged_in_employee_info();
        if (!$this->employee->isAdmin((int) $user->person_id)) {
            return $this->fail(lang('Sync.not_allowed'));
        }

        try {
            $this->sync->takeOver($user->username);
        } catch (Throwable $e) {
            return $this->fail($e->getMessage());
        }

        return $this->response->setJSON(['success' => true, 'message' => lang('Sync.take_over_done')]);
    }

    public function getTestConnection(): ResponseInterface
    {
        $reachable = $this->sync->cloudReachable();

        return $this->response->setJSON([
            'success' => $reachable,
            'message' => lang($reachable ? 'Sync.cloud_reachable' : 'Sync.cloud_unreachable_short'),
        ]);
    }

    /**
     * Every local table as SQL, for recovering work that can no longer be pushed.
     */
    public function getDownloadSnapshot(): ResponseInterface
    {
        $user = $this->employee->get_logged_in_employee_info();
        if (!$this->employee->isAdmin((int) $user->person_id)) {
            return $this->response->setStatusCode(403)->setBody(lang('Sync.not_allowed'));
        }

        return $this->response
            ->setHeader('Content-Type', 'application/sql')
            ->setHeader('Content-Disposition', 'attachment; filename="drawnonward-local-snapshot-' . date('Ymd-His') . '.sql"')
            ->setBody($this->sync->exportLocalSql());
    }

    private function fail(string $message): ResponseInterface
    {
        return $this->response->setJSON(['success' => false, 'message' => $message]);
    }
}
