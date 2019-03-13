from trio.hazmat import Task
from trio_typing import Nursery
from traceback import FrameSummary


def frame_summary_to_json(frame: FrameSummary):
    return {
        'lineno': frame.lineno,
        'line': frame.line,
        'filename': frame.filename,
        'name': frame.name
    }


def nursery_to_json(nursery: Nursery):
    return {
        'id': id(nursery),
        'name': '<nursery>',
        'tasks': [
            task_to_json(child) for child in nursery.child_tasks
        ]
    }


def task_to_json(task: Task):
    return {
        'id': id(task),
        'name': task.name,
        'nurseries': [
            nursery_to_json(nursery) for nursery in task.child_nurseries
        ]
    }
