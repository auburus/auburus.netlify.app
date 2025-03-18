---
title: "AsyncIO limits in python"
date: 2025-03-18T00:00:00+00:00
draft: false
---

A common problem when using asynIO's capabilities is that there is no backpressure,
so there is the risk of completely saturating an external service, like a 3rd party API.

See the following example of such an issue, where we are automatically enabling a
CoolNewFeature (TM) for our premium users.

```python
import asyncio
import httpx


async def enable_cool_feature(rest_client, user_id):
    await client.put(
        f"https://external.api/{user_id}", data={"cool_feature_enabled": True}
    )


async def main():
    async with httpx.AsyncClient() as client:
        tasks = [
            enable_cool_feature(client, user_id) for user_id in get_premium_users()
        ]

        # Wait until all tasks have finished
        await asyncio.gather(*tasks)


if __name__ == "__main__":
    asyncio.run(main())

```
About 2 minutes later, we'll be googling what exactly "429 Too Many Requests" means,
and why is the API returning that.

That happens because this code fires an HTTP request for each premium user as quick as possible,
and only after having started all those request doest it go back and checks the responses.


### Solution

A quick and nasty way to prevent the previous problem is to limit the amount of
"unfinished requests" to a reasonable number, and we can use asyncIO's **semaphore** for that.

```python {hl_lines=[6,14,15,19]}
import asyncio
import httpx


async def enable_cool_feature(semaphore, rest_client, user_id):
    async with semaphore:
        await client.put(
            f"https://external.api/{user_id}", data={"cool_feature_enabled": True}
        )


async def main():

    # Define how many tasks you want to allow concurrently
    semaphore = asyncio.Semaphore(5)

    async with httpx.AsyncClient() as client:
        tasks = [
            enable_cool_feature(semaphore, client, user_id)
            for user_id in get_premium_users()
        ]

        # Wait until all tasks have finished
        await asyncio.gather(*tasks)


if __name__ == "__main__":
    asyncio.run(main())

```

The important bit here is that all the tasks must receive the __same__ semaphore object.

The code still starts all tasks "concurrenly", but in this case only the first 5
will actually start doing any work. When is the turn of the rest of the tasks
will wake up, check if there is any slot available in the semaphore, and
claim it and start working if there is, or keep waiting otherwise.
