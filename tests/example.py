import trio
from random import randint
from trio_inspector import TrioInspector


async def sleep_seconds(seconds):
    await trio.sleep(seconds)


async def stubborn_spawner(n):
    while True:
        async with trio.open_nursery() as nursery:
            for i in range(n):
                nursery.start_soon(sleep_seconds, randint(1, 10))


async def child2():
    async with trio.open_nursery() as nursery:
        nursery.start_soon(trio.sleep_forever)
        nursery.start_soon(stubborn_spawner, 4)


async def child1():
    async with trio.open_nursery() as nursery:
        nursery.start_soon(child2)
        nursery.start_soon(child2)
        nursery.start_soon(trio.sleep_forever)


async def main():
    async with trio.open_nursery() as nursery0:
        nursery0.start_soon(TrioInspector().run)
        nursery0.start_soon(child1)
        async with trio.open_nursery() as nursery1:
            nursery1.start_soon(child1)


trio.run(main)
