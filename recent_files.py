#!/usr/bin/env python3
import os
import sys
import json
import sqlite3

def get_aliases(agent):
    s = agent.lower().strip()
    if s.endswith('.desktop'):
        s = s[:-8]
    if '/' in s:
        s = s.split('/')[-1]
    aliases = {s}
    
    if s.startswith('org.kde.'):
        aliases.add(s[8:])
    if s.startswith('com.'):
        aliases.add(s.split('.')[-1])
    if 'edge' in s:
        aliases.add('edge')
        aliases.add('microsoft-edge')
        aliases.add('com.microsoft.edge')
    if 'chrome' in s:
        aliases.add('google-chrome')
        aliases.add('chrome')
    if 'jetbrains-' in s:
        parts = s.split('-')
        if len(parts) >= 2:
            aliases.add(parts[1])
            aliases.add(f'jetbrains-{parts[1]}')
    if 'okular' in s:
        aliases.add('okular')
        aliases.add('org.kde.okular')
    if 'dolphin' in s:
        aliases.add('dolphin')
        aliases.add('org.kde.dolphin')
    if 'kate' in s:
        aliases.add('kate')
        aliases.add('org.kde.kate')
    if 'antigravity' in s:
        aliases.add('antigravity')
        aliases.add('antigravity-ide')
    return aliases

def main():
    db_path = os.path.expanduser('~/.local/share/kactivitymanagerd/resources/database')
    if not os.path.exists(db_path):
        print('{}')
        return

    cache_dir = os.path.expanduser('~/.cache/noctalia-qs')
    cache_path = os.path.join(cache_dir, 'recent_files_cache.json')

    try:
        db_mtime = os.path.getmtime(db_path)
    except OSError:
        db_mtime = 0

    # 1. Quick check: if database hasn't changed since last run, output cached JSON directly
    if db_mtime > 0 and os.path.exists(cache_path):
        try:
            with open(cache_path, 'r', encoding='utf-8') as f:
                cache = json.load(f)
                if cache.get('mtime') == db_mtime and 'data' in cache:
                    print(json.dumps(cache['data'], ensure_ascii=False))
                    return
        except Exception:
            pass

    # 2. Database updated or cache invalid -> query SQLite
    try:
        con = sqlite3.connect(f'file:{db_path}?mode=ro', uri=True)
        cur = con.cursor()
    except Exception as e:
        sys.stderr.write(f"Failed to open db: {e}\n")
        print('{}')
        return

    sql = '''
    SELECT c.initiatingAgent, c.targettedResource, COALESCE(NULLIF(i.title, ''), ''), COALESCE(NULLIF(i.mimetype, ''), ''), c.lastUpdate
    FROM ResourceScoreCache c
    LEFT JOIN ResourceInfo i ON c.targettedResource = i.targettedResource
    ORDER BY c.lastUpdate DESC
    '''

    home = os.path.expanduser('~')
    raw_by_agent = {}

    try:
        for agent, res, title, mime, last_up in cur.execute(sql):
            if not res:
                continue
            path = res[7:] if res.startswith('file://') else res
            # Check file existence to avoid dead links
            if not os.path.exists(path):
                continue
            if agent not in raw_by_agent:
                raw_by_agent[agent] = []
            raw_by_agent[agent].append({
                'path': path,
                'title': title if title else os.path.basename(path.rstrip('/')),
                'displayPath': '~' + path[len(home):] if path.startswith(home) else path,
                'isDir': os.path.isdir(path),
                'mimetype': mime,
                'time': last_up
            })
    except Exception as e:
        sys.stderr.write(f"Query error: {e}\n")

    con.close()

    # Map to aliases
    mapped = {}
    for agent, items in raw_by_agent.items():
        aliases = get_aliases(agent)
        for alias in aliases:
            if alias not in mapped:
                mapped[alias] = []
            mapped[alias].extend(items)

    # Deduplicate by path and limit
    final_data = {}
    for alias, items in mapped.items():
        seen = set()
        deduped = []
        items.sort(key=lambda x: x['time'], reverse=True)
        for it in items:
            if it['path'] not in seen:
                seen.add(it['path'])
                deduped.append(it)
                if len(deduped) >= 10:
                    break
        final_data[alias] = deduped

    # 3. Save to cache
    try:
        os.makedirs(cache_dir, exist_ok=True)
        with open(cache_path, 'w', encoding='utf-8') as f:
            json.dump({'mtime': db_mtime, 'data': final_data}, f, ensure_ascii=False)
    except Exception as e:
        sys.stderr.write(f"Failed to write cache: {e}\n")

    print(json.dumps(final_data, ensure_ascii=False))

if __name__ == '__main__':
    main()
