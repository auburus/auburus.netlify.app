---
title: "AsyncIO pool in python"
date: 2024-12-02T21:00:00+02:00
draft: false
---

In devops world I tend to have a lot of tasks that are IO-bound and completely independent,
so they are the perfect target for python's asyncIO module.

A typical code that acts on a bunch of different git repositories may look like this:

```python
#!/usr/bin/env python3
import time
import random

def do_stuff(repo):
    time.sleep(random.random())
    print(repo)

def main():
    repos = ['a', 'b', 'c']

    # Sequentially do work on each repo
    for repo in repos:
        do_stuff(repo)

if __name__ == "__main__":
    main()
```

This code, at an average of 0.5s per repo, takes almost a minute for 100 repositories!
We can obviously do better than that, even with python and the GIL.

My first attempt at this was just plain **wrong**, but it was based on the idea that I should be able to
create all the tasks and `asyncio.gather` them, and in theory that would just run things concurrently.

```python
import asyncio
import random

async def do_stuff(repo):
    await asyncio.sleep(random.random())
    print(repo)

async def main():
    repos = ['a', 'b', 'c']

    # Start ALL tasks
    tasks = [do_stuff(repo) for repo in repos]

    # Wait until all tasks have finished
    await asyncio.gather(*tasks)

if __name__ == "__main__":
    asyncio.run(main())
```

This code suffers from a problem that is not obvious, which is that doing everything concurrently is is too much!
Imagine than `do_stuff` is firing an HTTP request, then this code
would fire as many request as there are repositories, and then start listening for the responses. Likely
we will get a `Too Many Requests` response in some of those!


What we typically want is not a firehose of tasks, and complete them as quick as possible, but to put a limit
of some sort to only work on a subset of tasks on a given time.
Following our previous example, we want to just do 5 HTTP requests at a time, and only after
we've finished any of those we kick off the next one.

We can limit asyncio's tasks with a `Semaphore` (and its very special syntax).

```python
#!/usr/bin/env python3
import asyncio
import random

async def do_stuff(semaphore, repo):
    # Skip until a semaphore slot is available
    async with semaphore:
        await asyncio.sleep(random.random())
        print(repo)

async def main():
    repos = ['a', 'b', 'c']

    # Define how many tasks you want to allow concurrently
    semaphore = asyncio.Semaphore(5)
    tasks = [do_stuff(semaphore, repo) for repo in repos]

    # Wait until all tasks have finished
    await asyncio.gather(*tasks)

if __name__ == "__main__":
    asyncio.run(main())
```

The important bit here is that all the tasks must receive the **same** semaphore object.

The code still starts all tasks concurrenly, but in this case only the first 5
will actually start doing any work. When is the turn of the rest of the tasks they will wake up, check if there is
any slot available in the semaphore, and claim it and start working if there is, or keep waiting otherwise.

#### Final touches

There is one final improvement we can do, which is try to keep all semaphore specific code
outside of the `do_stuff` function, to avoid having to change the function signature. To accomplish that we
can introduce an intermediate function (we're calling it `run_limited`), than can be easily copy-pasted accross projects:

```python
import asyncio
import random

async def do_stuff(repo):
    await asyncio.sleep(random.random())
    print(repo)

# Intermediate task that handles the semaphore logic, and
# calls the real function once available
async def run_limited(semaphore, fun, *args, **kwargs):
    async with semaphore:
        return await fun(*args, **kwargs)

async def main():
    repos = ['a', 'b', 'c']

    # Define how many tasks you want to allow concurrently
    semaphore = asyncio.Semaphore(5)
    tasks = [run_limited(semaphore, do_stuff, repo) for repo in repos]

    # Wait until all tasks have finished
    await asyncio.gather(*tasks)

if __name__ == "__main__":
    asyncio.run(main())

```

The obvious downside of this approach is that `*args` and `**kwargs` completely break IDE's
ability to autocomplete. Tradeoffs, tradeoffs...
