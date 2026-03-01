import typing

from django.utils.translation import gettext
from django.templatetags.static import static
from uds.REST.methods.client import CLIENT_VERSION


# all plugins are under url clients...
PLUGINS: typing.Final[list[dict[str, 'str|bool']]] = [
    {
        'url': static('clients/' + url.format(version=CLIENT_VERSION)),
        'description': description,
        'name': name,
        'legacy': legacy,
    }
    for url, description, name, legacy in (
        (
            'FSOFT Virtual Desktop Client.msi',
            gettext('Windows Client using FSOFT Virtual Desktop Client.msi from client'),
            'Windows',
            False,
        ),
        (
            'MAC_Client.pkg', 
            gettext('MAC Client (Apple Silicon)'), 
            'MacOS', 
            False
        ),
        (
            'MAC_Client.pkg', 
            gettext('MAC Client (Intel)'), 
            'MacOS', 
            False
        ),
        (
            'udsclient3-{version}.tar.gz',
            gettext('Linux build new for linux client'),
            'Linux',
            False,
        ),
    )
]
