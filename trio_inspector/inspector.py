import json
import math
import os.path

import trio
import trio.testing
from hypercorn.config import Config as HyperConfig
from hypercorn.trio import serve
from quart.logging import create_serving_logger
from quart_cors import cors
from quart_trio import QuartTrio
from trio.hazmat import Task, current_task


class TrioInspector(trio.abc.Instrument):
    def __init__(self, host="127.0.0.1", port=5000):
        self._host = host
        self._port = port

    def before_run(self):
        print("!!! run started")

    def _print_with_task(self, msg, task):
        # repr(task) is perhaps more useful than task.name in general,
        # but in context of a tutorial the extra noise is unhelpful.
        print("{}: {}".format(msg, task.name))

    def task_spawned(self, task):
        self._print_with_task("### new task spawned", task)

    def task_scheduled(self, task):
        self._print_with_task("### task scheduled", task)

    def before_task_step(self, task):
        self._print_with_task(">>> about to run one step of task", task)

    def after_task_step(self, task):
        self._print_with_task("<<< task step finished", task)

    def task_exited(self, task):
        self._print_with_task("### task exited", task)

    def before_io_wait(self, timeout):
        if timeout:
            print("### waiting for I/O for up to {} seconds".format(timeout))
        else:
            print("### doing a quick check for I/O")
        self._sleep_time = trio.current_time()

    def after_io_wait(self, timeout):
        duration = trio.current_time() - self._sleep_time
        print("### finished I/O check (took {} seconds)".format(duration))

    def after_run(self):
        print("!!! run finished")

    @staticmethod
    def get_root_task() -> Task:
        task = current_task()
        while task.parent_nursery is not None:
            task = task.parent_nursery.parent_task
        return task

    async def dispatch_task_tree(self):
        root_task = TrioInspector.get_root_task()
        def nursery_to_json(nursery):
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
        return json.dumps(task_to_json(root_task))

    async def dispatch_stats(self):
        stats = trio.hazmat.current_statistics()
        seconds_to_next_deadline = None \
                if math.isinf(stats.seconds_to_next_deadline) \
                else stats.seconds_to_next_deadline

        return json.dumps({
            'tasks_living': stats.tasks_living,
            'tasks_runnable': stats.tasks_runnable,
            'seconds_to_next_deadline': seconds_to_next_deadline,
            'run_sync_soon_queue_size': stats.run_sync_soon_queue_size,
            'io_statistics_backend': stats.io_statistics.backend
        })

    async def run(self):
        # Serve static files from ./static
        static_folder = os.path.join(os.path.dirname(__file__), 'static')
        app = QuartTrio(__name__, static_folder=static_folder)
        app.add_url_rule('/', 'static', app.send_static_file, defaults={
            'filename': 'index.html'
        })
        app.add_url_rule('/<path:filename>', 'static', app.send_static_file)

        app.add_url_rule('/tasks.json', 'task_tree', self.dispatch_task_tree, ['GET'])
        app.add_url_rule('/stats.json', 'stats', self.dispatch_stats, ['GET'])

        config = HyperConfig()
        #config.access_log_format = '%(h)s %(r)s %(s)s %(b)s %(D)s'
        #config.access_logger = create_serving_logger()  # type: ignore
        config.bind = [f'{self._host}:{self._port}']
        config.error_logger = config.access_logger  # type: ignore

        #trio.hazmat.add_instrument(self)
        await serve(cors(app), config)
        #trio.hazmat.remove_instrument(self)
