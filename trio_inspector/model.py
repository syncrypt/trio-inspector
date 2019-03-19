from typing import Optional

from trio.hazmat import Task, current_task
from trio_typing import Nursery


def get_root_task() -> Task:
    task = current_task()
    while task.parent_nursery is not None:
        task = task.parent_nursery.parent_task
    return task


def find_task_by_id(task_id: int) -> Optional[Task]:
    root_task = get_root_task()
    def _find_task_by_id(task, task_id):
        if id(task) == task_id:
            return task
        for nursery in task.child_nurseries:
            for child in nursery.child_tasks:
                maybe_task = _find_task_by_id(child, task_id)
                if maybe_task:
                    return maybe_task
        return None
    return _find_task_by_id(root_task, task_id)


def find_nursery_by_id(task_id: int) -> Optional[Nursery]:
    root_task = get_root_task()
    def _find_task_by_id(task, task_id):
        if id(task) == task_id:
            return task
        for nursery in task.child_nurseries:
            for child in nursery.child_tasks:
                maybe_task = _find_task_by_id(child, task_id)
                if maybe_task:
                    return maybe_task
        return None
    return _find_task_by_id(root_task, task_id)



def walk_coro_stack(coro):
    while coro is not None:
        if hasattr(coro, "cr_frame"):
            # A real coroutine
            yield coro.cr_frame, coro.cr_frame.f_lineno
            coro = coro.cr_await
        else:
            # A generator decorated with @types.coroutine
            yield coro.gi_frame, coro.gi_frame.f_lineno
            coro = coro.gi_yieldfrom
