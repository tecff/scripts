#!/usr/bin/env python3
# developed by @fpletz for @freifunkMUC
# https://github.com/freifunkMUC/stats-tools/blob/master/nodes2graphite.py

import sys
import json
import pickle
import struct
from time import time

def get_metrics(timestamp, stats, prefix=''):
    for k,v in stats.items():
        key = '.'.join([prefix, k])
        if type(v) is dict:
            for i in get_metrics(timestamp, v, key):
                yield i
        elif type(v) is not str:
            yield (key, (timestamp, v))

def load_metrics(f):
    nodes = json.load(f)
    ts = int(time())
    online_nodes = 0
    total_clients = 0
    for (node_id,node_data) in nodes['nodes'].items():
        for m in get_metrics(ts, node_data['statistics'], 'nodes.' + node_id):
            yield m
        if 'clients' in node_data['statistics']:
            total_clients += node_data['statistics']['clients']
        if node_data['flags']['online']: online_nodes += 1

    yield ('node-stats.online', (ts, online_nodes))
    yield ('node-stats.clients', (ts, total_clients))

def get_pickled_msg(metrics):
    payload = pickle.dumps(list(metrics), protocol=2)
    header = struct.pack("!L", len(payload))
    return header + payload

def main():
    with open(sys.argv[1], encoding='utf-8') as data_file:
        metrics = load_metrics(data_file)
        for (k,(t,v)) in metrics:
            print(' '.join(map(str, [k,v,t])))

if __name__ == '__main__':
    main()
