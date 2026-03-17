# -*- coding: utf-8 -*-
#
# Copyright (c) 2022 Virtual Cable S.L.U.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
#    * Redistributions of source code must retain the above copyright notice,
#      this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright notice,
#      this list of conditions and the following disclaimer in the documentation
#      and/or other materials provided with the distribution.
#    * Neither the name of Virtual Cable S.L. nor the names of its contributors
#      may be used to endorse or promote products derived from this software
#      without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
'''
Author: Adolfo Gómez, dkmaster at dkmon dot com
'''
import multiprocessing
import socket
import time
import logging
import typing
import io
import asyncio
import ssl
import logging
import typing


from . import config
from . import consts


if typing.TYPE_CHECKING:
    from multiprocessing.managers import Namespace, SyncManager

INTERVAL = 2  # Interval in seconds between stats update

logger = logging.getLogger(__name__)

class StatsSingleCounter:
    def __init__(self, parent: 'StatsManager', for_receiving=True) -> None:
        if for_receiving:
            self.adder = parent.add_recv
        else:
            self.adder = parent.add_sent

    def add(self, value: int):
        self.adder(value)
        return self


class StatsManager:
    ns: 'Namespace'
    last_sent: int
    sent: int
    last_recv: int
    recv: int
    last: float
    start_time: float  # timestamp
    end_time: float

    # Latency tracking
    latency_sum: float  # Sum of all latency measurements
    latency_count: int  # Number of latency measurements
    latency_min: float  # Minimum latency
    latency_max: float  # Maximum latency

    # Last timestamp for RTT calculation
    _last_sent_time: float
    _last_recv_time: float
    _pending_sent_times: typing.Dict[int, float]  # seq -> timestamp

    def __init__(self, ns: 'Namespace'):
        self.ns = ns
        self.sent = self.last_sent = 0
        self.recv = self.last_recv = 0
        self.last = time.monotonic()
        self.start_time = time.monotonic()
        self.end_time = self.start_time

        # Initialize latency tracking
        self.latency_sum = 0.0
        self.latency_count = 0
        self.latency_min = float('inf')
        self.latency_max = 0.0
        self._last_sent_time = 0.0
        self._last_recv_time = 0.0
        self._pending_sent_times = {}

    @property
    def current_time(self) -> float:
        return time.monotonic()

    @property
    def latency_avg(self) -> float:
        """Average latency in milliseconds"""
        if self.latency_count == 0:
            return 0.0
        return (self.latency_sum / self.latency_count) * 1000.0

    @property
    def latency_min_ms(self) -> float:
        """Minimum latency in milliseconds"""
        return self.latency_min * 1000.0 if self.latency_min != float('inf') else 0.0

    @property
    def latency_max_ms(self) -> float:
        """Maximum latency in milliseconds"""
        return self.latency_max * 1000.0

    def add_latency(self, latency_seconds: float) -> None:
        """Record a latency measurement"""
        self.latency_sum += latency_seconds
        self.latency_count += 1
        if latency_seconds < self.latency_min:
            self.latency_min = latency_seconds
        if latency_seconds > self.latency_max:
            self.latency_max = latency_seconds

    def update(self, force: bool = False):
        now = time.monotonic()
        if force or now - self.last > INTERVAL:
            self.last = now
            self.ns.recv += self.recv - self.last_recv
            self.ns.sent += self.sent - self.last_sent
            self.last_sent = self.sent
            self.last_recv = self.recv
            # Update latency stats
            self.ns.latency_avg = self.latency_avg
            self.ns.latency_min = self.latency_min_ms
            self.ns.latency_max = self.latency_max_ms

    def add_recv(self, size: int) -> None:
        self.recv += size
        now = time.monotonic()
        # Track RTT if we have pending sent timestamps
        if self._pending_sent_times:
            # Use the oldest pending timestamp for RTT estimation
            oldest_seq = min(self._pending_sent_times.keys())
            sent_time = self._pending_sent_times.pop(oldest_seq)
            rtt = now - sent_time
            self.add_latency(rtt)
        self._last_recv_time = now
        self.update()

    def add_sent(self, size: int) -> None:
        self.sent += size
        now = time.monotonic()
        # Store timestamp for RTT calculation (use sent count as sequence)
        self._pending_sent_times[self.sent] = now
        self._last_sent_time = now
        self.update()

    def decrement_connections(self):
        # Decrement current runing connections
        self.ns.current -= 1

    def increment_connections(self):
        # Increment current runing connections
        # Also, increment total connections
        self.ns.current += 1
        self.ns.total += 1

    @property
    def as_sent_counter(self) -> 'StatsSingleCounter':
        return StatsSingleCounter(self, False)

    @property
    def as_recv_counter(self) -> 'StatsSingleCounter':
        return StatsSingleCounter(self, True)

    def close(self):
        self.update(True)
        self.decrement_connections()
        self.end_time = time.monotonic()

# Stats collector thread
class GlobalStats:
    manager: 'SyncManager'
    ns: 'Namespace'
    counter: int

    def __init__(self):
        super().__init__()
        self.manager = multiprocessing.Manager()
        self.ns = self.manager.Namespace()

        # Counters
        self.ns.current = 0
        self.ns.total = 0
        self.ns.sent = 0
        self.ns.recv = 0
        # Latency counters (average across all sessions)
        self.ns.latency_avg = 0.0
        self.ns.latency_min = 0.0
        self.ns.latency_max = 0.0
        self.counter = 0

    def info(self) -> typing.Iterable[str]:
        return GlobalStats.get_stats(self.ns)

    @staticmethod
    def get_stats(ns: 'Namespace') -> typing.Iterable[str]:
        yield ';'.join([
            str(ns.current),
            str(ns.total),
            str(ns.sent),
            str(ns.recv),
            f'{float(ns.latency_avg):.2f}',
            f'{float(ns.latency_min):.2f}',
            f'{float(ns.latency_max):.2f}'
        ])

# Stats processor, invoked from command line
async def getServerStats(detailed: bool = False) -> None:
    cfg = config.read()

    # Context for local connection (ignores cert hostname)
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE  # For ServerStats, does not checks certificate

    try:
        host = cfg.listen_address if cfg.listen_address != '0.0.0.0' else 'localhost'
        reader: asyncio.StreamReader
        writer: asyncio.StreamWriter

        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.connect((host, cfg.listen_port))
            # Send HANDSHAKE
            sock.sendall(consts.HANDSHAKE_V1)
            # Ugrade connection to TLS
            reader, writer = await asyncio.open_connection(sock=sock, ssl=context, server_hostname=host)

            tmpdata = io.BytesIO()
            cmd = consts.COMMAND_STAT if detailed else consts.COMMAND_INFO
            
            writer.write(cmd + cfg.secret.encode())           
            await writer.drain()

            while True:
                chunk = await reader.read(consts.BUFFER_SIZE)
                if not chunk:
                    break
                tmpdata.write(chunk)

        # Now we can output chunk data
        print(tmpdata.getvalue().decode())
    except Exception as e:
        print(e)
        return
