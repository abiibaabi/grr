#!/usr/bin/env python
"""Raw access server-side only API shell."""

import os
import sys


# pylint: disable=unused-import,g-bad-import-order
from grr.server.grr_response_server import server_plugins
# pylint: enable=g-bad-import-order


from grr import config
from grr_api_client import api
from grr_api_client import api_shell_lib
from grr.config import contexts
from grr.config import server as config_server
from grr.core.grr_response_core.lib import flags
from grr.server.grr_response_server import access_control
from grr.server.grr_response_server import fleetspeak_connector
from grr.server.grr_response_server import server_startup
from grr.server.grr_response_server.bin import api_shell_raw_access_lib

flags.DEFINE_integer(
    "page_size", 1000,
    "Page size used when paging through collections of items. Default is 1000.")

flags.DEFINE_string(
    "username", None, "Username to use when making raw API calls. If not "
    "specified, USER environment variable value will be used.")

flags.DEFINE_string(
    "exec_code", None,
    "If present, no IPython shell is started but the code given in "
    "the flag is run instead (comparable to the -c option of "
    "IPython). The code will be able to use a predefined "
    "global 'grrapi' object.")

flags.DEFINE_string(
    "exec_file", None,
    "If present, no IPython shell is started but the code given in "
    "command file is supplied as input instead. The code "
    "will be able to use a predefined global 'grrapi' "
    "object.")

flags.DEFINE_version(config_server.VERSION["packageversion"])


def main(argv=None):
  del argv  # Unused.

  config.CONFIG.AddContext(contexts.COMMAND_LINE_CONTEXT)
  config.CONFIG.AddContext(contexts.CONSOLE_CONTEXT,
                           "Context applied when running the console binary.")
  server_startup.Init()
  fleetspeak_connector.Init()

  username = flags.FLAGS.username
  if not username:
    username = os.environ["USER"]

  if not username:
    print("Username has to be specified with either --username flag or "
          "USER environment variable.")
    sys.exit(1)

  grrapi = api.GrrApi(
      connector=api_shell_raw_access_lib.RawConnector(
          token=access_control.ACLToken(username=username),
          page_size=flags.FLAGS.page_size))

  if flags.FLAGS.exec_code and flags.FLAGS.exec_file:
    print "--exec_code --exec_file flags can't be supplied together."
    sys.exit(1)
  elif flags.FLAGS.exec_code:
    # pylint: disable=exec-used
    exec (flags.FLAGS.exec_code, dict(grrapi=grrapi))
    # pylint: enable=exec-used
  elif flags.FLAGS.exec_file:
    execfile(flags.FLAGS.exec_file, dict(grrapi=grrapi))
  else:
    api_shell_lib.IPShell([sys.argv[0]], user_ns=dict(grrapi=grrapi))


if __name__ == "__main__":
  flags.StartMain(main)