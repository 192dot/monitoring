#!/usr/bin/env python
"""This script complements a pull-based Prometheus with a push-based monitoring.
The purpose is to distinguish between a node being down (which is more serious)
to a Prometheus exporter being down (which is usually less serious).

Example, on a Prometheus server (with Pushgateway installed), run

  $ python check_ping.py

This script sends an ICMP ping to the targets.
If ping is up, node_ping_alive metric will record value 1.
If ping is down, node_ping_alive metric will record value 0.
This assumes Pushgateway does not require authentication.
On a production system, please either lock down the Pushgateway port or add authentication.
"""
import os
import requests
import json
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway


def main():
    """
    main program
    """
    registry = CollectorRegistry()
    gauge = Gauge('node_ping_alive', 'Ping status to host', ['hostname'], registry=registry)

    # get targets
    hosts = get_hosts()

    for hostname in hosts:
        response = check_ping(hostname)
        gauge.labels(hostname).set(response)
        push_to_gateway('localhost:9091', job='push_ping', registry=registry)

    return


def get_hosts():
    """Get monitoring targets excluding localhost"""
    hosts = []
    prometheus_url = 'http://localhost:9090/api/v1/targets'
    x = requests.get(prometheus_url)
    content = x.content
    all_json = json.loads(content)
    active_targets = all_json['data']['activeTargets']
    for target in active_targets:
        hostname = target['discoveredLabels']['__address__']
        if hostname.startswith('localhost'):
            continue
        hosts.append(hostname)
    return hosts


def check_ping(hostname):
    """Check ping response to a host. Returns 1 when up, 0 when down"""
    response = os.system("ping -c 1 {}".format(hostname))

    if response == 0:
        print('Host {} is up'.format(hostname))
        return 1
    print('Host {} is down'.format(hostname))
    return 0


if __name__ == '__main__':
    main()
