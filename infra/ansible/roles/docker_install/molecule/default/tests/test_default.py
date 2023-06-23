"""Role testing files using testinfra."""

def test_package(host):
    p = host.package('docker')

    assert p.is_installed


def test_service(host):
    s = host.service('docker')

    assert s.is_enabled


def test_nginx(host):
    s = host.service('docker')

    assert s.is_running


def test_ports(host):
    s = host.socket("tcp://0.0.0.0:80")

    assert s.is_listening
