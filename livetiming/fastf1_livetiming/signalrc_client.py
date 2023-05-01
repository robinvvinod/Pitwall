"""
This script was originally written by Philipp Schäfer for the Fast-F1 package (https://github.com/theOehrly/Fast-F1/blob/master/fastf1/livetiming/client.py)
Parts of the script have been modified to support live processing of the captured data instead of writing to a file
"""

import asyncio
import concurrent.futures
import logging
import requests
import time

from livetiming.signalr_aio import Connection


class SignalRClient:
    """A client for receiving and saving F1 timing data which is streamed
    live over the SignalR protocol.

    During an F1 session, timing data and telemetry data are streamed live
    using the SignalR protocol. This class can be used to connect to the
    stream and save the received data into a file.

    The data will be saved in a raw text format without any postprocessing.
    It is **not** possible to use this data during a session. Instead, the
    data can be processed after the session using the :mod:`fastf1.api` and
    :mod:`fastf1.core`

    Args:
        topics (list[str]) : List of topics to subscribe to in SignalR broadcast
        processor (livetiming.process_livedata.ProcessLiveData) : Instance of ProcessLiveData class to
            be called on receiving message
        timeout (int, optional) : Number of seconds after which the client
            will automatically exit when no message data is received.
            Set to zero to disable.
        logger (Logger or None) : By default, errors are logged to the
            console. If you wish to customize logging, you can pass an
            instance of :class:`logging.Logger` (see: :mod:`logging`).
    """

    _connection_url = "https://livetiming.formula1.com/signalr"

    def __init__(self, topics, processor, timeout=60, logger=None):
        self.headers = {
            "User-agent": "BestHTTP",
            "Accept-Encoding": "gzip, identity",
            "Connection": "keep-alive, Upgrade",
        }

        self.topics = topics
        self._processor = processor
        self.timeout = timeout
        self._connection = None
        self._tsince_last_message = None

        if not logger:
            logging.basicConfig(format="%(asctime)s - %(levelname)s: %(message)s")
            self.logger = logging.getLogger("SignalR")
        else:
            self.logger = logger

    async def _on_message(self, msg):
        self._tsince_last_message = time.time()
        try:
            await self._processor.process(topic=msg[0], msg=msg[1], timestamp=[msg[2]])
        except:
            self.logger.exception("Exception while processing live data")

    async def _run(self):
        await self._processor.start()

        # Create connection
        session = requests.Session()
        session.headers = self.headers
        self._connection = Connection(self._connection_url, session=session)

        # Register hub
        hub = self._connection.register_hub("Streaming")
        # Assign hub message handler
        hub.client.on("feed", self._on_message)
        hub.server.invoke("Subscribe", self.topics)

        # Start the client
        loop = asyncio.get_event_loop()
        with concurrent.futures.ThreadPoolExecutor() as pool:
            await loop.run_in_executor(pool, self._connection.start)

    async def _supervise(self):
        self._tsince_last_message = time.time()
        while True:
            if (
                self.timeout != 0
                and time.time() - self._tsince_last_message > self.timeout
            ):
                self.logger.warning(
                    f"Timeout - received no data for more "
                    f"than {self.timeout} seconds!"
                )
                self._connection.close()
                await self._processor.stop()
                return
            await asyncio.sleep(1)

    async def start(self):
        self.logger.info(f"Starting FastF1 live timing client")
        await asyncio.gather(
            asyncio.ensure_future(self._supervise()),
            asyncio.ensure_future(self._run()),
        )
        self.logger.warning("Exiting...")
