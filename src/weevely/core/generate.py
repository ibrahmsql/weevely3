import base64
import os
import sys

from mako.template import Template

from . import messages
from .config import agent_templates_folder_path
from .config import obfuscators_templates_folder_path
from .weexceptions import FatalException


def generate(password, obfuscator="phar", agent="obfpost_php"):
    
    # Auto-detect agent based on extension if not specified or default
    if agent == "obfpost_php":
        # If the user didn't specify a custom agent, try to infer from output filename if possible
        # But generate() doesn't know the output filename directly here, it returns the content.
        # However, the caller usually handles this. 
        # Let's rely on the 'agent' argument being passed correctly or default to php.
        pass

    # Map extensions/types to templates
    # This is a bit hacky because 'agent' arg is usually the template name.
    # We will assume the user passes 'obfpost_jsp' or 'obfpost_aspx' if they want those.
    
    # Auto-detect based on output path extension if agent is default
    if agent == "obfpost_php" and hasattr(password, 'path') and password.path: 
        # Note: password arg here is just the password string, we don't have path here easily 
        # unless we change the signature or caller.
        # But wait, the caller in main.py passes arguments.agent.
        pass

    obfuscator_path = os.path.join(obfuscators_templates_folder_path, obfuscator + ".tpl")
    agent_path = os.path.join(agent_templates_folder_path, agent + ".tpl")

    for path in (obfuscator_path, agent_path):
        if not os.path.isfile(path):
            raise FatalException(messages.generic.file_s_not_found % path)

    obfuscator_template = Template(filename=obfuscator_path)

    try:
        with open(agent_path) as templatefile:
            agent = Template(templatefile.read()).render(password=password).encode("utf-8")

    except Exception as e:
        raise FatalException(messages.generate.error_agent_template_s_s % (agent_path, str(e)))

    try:
        obfuscated = obfuscator_template.render(agent=agent)
    except Exception as e:
        raise FatalException(messages.generate.error_obfuscator_template_s_s % (obfuscator_path, str(e)))

    return obfuscated


def save_generated(obfuscated, output):
    b64 = obfuscated[:4] == "b64:"
    final = base64.b64decode(obfuscated[4:]) if b64 else obfuscated.encode("utf-8")
    try:
        if output == "-":
            sys.stdout.buffer.write(final)
        else:
            with open(output, "wb") as outfile:
                outfile.write(final)
    except Exception as e:
        raise FatalException(messages.generic.error_creating_file_s_s % (output, e))
