import trio
from trio_inspector import TrioInspector


async def child2():
    async with trio.open_nursery() as nursery:
        nursery.start_soon(trio.sleep_forever)
        nursery.start_soon(trio.sleep_forever)


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
