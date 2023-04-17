"""
This script was originally written by Philipp Schäfer for the Fast-F1 package (https://github.com/theOehrly/Fast-F1/blob/master/fastf1/livetiming/client.py)
Parts of the script have been modified to support live processing of the captured data instead of writing to a file
"""

import asyncio
import concurrent.futures
import logging
import requests
import time

from ..signalr_aio import Connection


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
        filename (str) : filename (opt. with path) for the output file
        filemode (str, optional) : one of 'w' or 'a'; append to or overwrite
            file content it the file already exists. Append-mode may be useful
            if the client is restarted during a session.
        timeout (int, optional) : Number of seconds after which the client
            will automatically exit when no message data is received.
            Set to zero to disable.
        logger (Logger or None) : By default, errors are logged to the
            console. If you wish to customize logging, you can pass an
            instance of :class:`logging.Logger` (see: :mod:`logging`).
    """

    _connection_url = "https://livetiming.formula1.com/signalr"

    def __init__(self, filename, filemode="w", timeout=60, logger=None):
        self.headers = {
            "User-agent": "BestHTTP",
            "Accept-Encoding": "gzip, identity",
            "Connection": "keep-alive, Upgrade",
        }

        self.topics = [
            "Heartbeat",
            "CarData.z",
            "Position.z",
            "ExtrapolatedClock",
            "TopThree",
            "RcmSeries",
            "TimingStats",
            "TimingAppData",
            "WeatherData",
            "TrackStatus",
            "DriverList",
            "RaceControlMessages",
            "SessionInfo",
            "SessionData",
            "LapCount",
            "TimingData",
        ]

        self.filename = filename
        self.filemode = filemode
        self.timeout = timeout
        self._connection = None

        if not logger:
            logging.basicConfig(format="%(asctime)s - %(levelname)s: %(message)s")
            self.logger = logging.getLogger("SignalR")
        else:
            self.logger = logger

        self._output_file = None
        self._t_last_message = None

    def _to_file(self, msg):
        # self._output_file.write(msg + '\n')
        # self._output_file.flush()

        # Check if the msg is in utf-8-sig and account for the BOM accordingly
        # process_livedata(msg)
        pass

    async def _on_message(self, msg):
        self._t_last_message = time.time()
        loop = asyncio.get_running_loop()
        try:
            with concurrent.futures.ThreadPoolExecutor() as pool:
                await loop.run_in_executor(pool, self._to_file, str(msg))
        except Exception:
            self.logger.exception("Exception while writing message to file")

    async def _run(self):
        self._output_file = open(self.filename, self.filemode)
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
        self._t_last_message = time.time()
        while True:
            if self.timeout != 0 and time.time() - self._t_last_message > self.timeout:
                self.logger.warning(
                    f"Timeout - received no data for more "
                    f"than {self.timeout} seconds!"
                )
                self._connection.close()
                return
            await asyncio.sleep(1)

    async def _async_start(self):
        self.logger.info(f"Starting FastF1 live timing client")
        await asyncio.gather(
            asyncio.ensure_future(self._supervise()),
            asyncio.ensure_future(self._run()),
        )
        self._output_file.close()
        self.logger.warning("Exiting...")

    def start(self):
        """Connect to the data stream and start writing the data to a file."""
        try:
            asyncio.run(self._async_start())
        except KeyboardInterrupt:
            self.logger.warning("Keyboard interrupt - exiting...")
            return
