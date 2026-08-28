#!/usr/bin/env python3
"""
OpenCode collector for Omarchy agents plugin.
Reads session data from opencode.db and outputs JSON record.
"""

import json
import os
import subprocess
import sys
import sqlite3
from pathlib import Path
from datetime import datetime, timedelta

def get_db_path():
    """Get OpenCode database path."""
    data_dir = os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local" / "share"))
    return Path(data_dir) / "opencode" / "opencode.db"

def get_sessions(db_path, limit=20):
    """Get recent sessions from database."""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT 
            id,
            title,
            model,
            agent,
            tokens_input,
            tokens_output,
            tokens_reasoning,
            tokens_cache_read,
            tokens_cache_write,
            cost,
            time_created,
            time_updated,
            project_id
        FROM session
        ORDER BY time_updated DESC
        LIMIT ?
    """, (limit,))
    
    sessions = []
    for row in cursor.fetchall():
        try:
            agent_data = json.loads(row['agent']) if row['agent'] else {}
        except json.JSONDecodeError:
            agent_data = {}
        
        # Extract model ID from JSON if needed
        model = row['model']
        try:
            model_data = json.loads(model) if model and model.startswith('{') else {}
            model = model_data.get('id', model)
        except json.JSONDecodeError:
            pass
        
        sessions.append({
            "id": row['id'],
            "title": row['title'],
            "model": model,
            "provider": agent_data.get('providerID', 'unknown'),
            "tokens_input": row['tokens_input'],
            "tokens_output": row['tokens_output'],
            "tokens_reasoning": row['tokens_reasoning'],
            "tokens_cache_read": row['tokens_cache_read'],
            "tokens_cache_write": row['tokens_cache_write'],
            "total_tokens": row['tokens_input'] + row['tokens_output'] + row['tokens_reasoning'],
            "cost": row['cost'],
            "time_created": row['time_created'],
            "time_updated": row['time_updated'],
            "project_id": row['project_id']
        })
    
    conn.close()
    return sessions

def get_models(db_path):
    """Get list of available models (from the DB history)."""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT DISTINCT model
        FROM session
        WHERE model IS NOT NULL AND model != ''
        ORDER BY time_updated DESC
    """)
    
    models = []
    for row in cursor.fetchall():
        raw = row[0]
        provider = ""
        model_id = raw
        try:
            data = json.loads(raw) if raw and raw.startswith('{') else {}
            model_id = data.get('id', raw)
            provider = data.get('providerID', '')
        except json.JSONDecodeError:
            pass
        entry = {
            "id": model_id,
            "provider": provider,
            "full": (provider + "/" + model_id) if provider and model_id else model_id
        }
        full = entry["full"]
        if not any(m["full"] == full for m in models):
            models.append(entry)
    conn.close()
    return models

def get_available_models():
    """List models actually selectable via `opencode models`."""
    try:
        out = subprocess.run(
            ["opencode", "models"],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "NO_COLOR": "1"}
        ).stdout
        models = []
        for line in out.splitlines():
            line = line.strip()
            if not line or line.startswith("("):
                continue
            provider = ""
            model_id = line
            if "/" in line:
                provider, model_id = line.split("/", 1)
            models.append({"id": model_id, "provider": provider, "full": line})
        return models
    except Exception:
        return []

def get_stats(db_path):
    """Get usage statistics."""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    now = datetime.now()
    today_start = int(now.replace(hour=0, minute=0, second=0, microsecond=0).timestamp() * 1000)
    week_start = int((now - timedelta(days=7)).replace(hour=0, minute=0, second=0, microsecond=0).timestamp() * 1000)
    
    # Today's stats
    cursor.execute("""
        SELECT COUNT(*), COALESCE(SUM(tokens_input + tokens_output + tokens_reasoning), 0), COALESCE(SUM(cost), 0)
        FROM session
        WHERE time_updated >= ?
    """, (today_start,))
    today = cursor.fetchone()
    
    # This week's stats
    cursor.execute("""
        SELECT COUNT(*), COALESCE(SUM(tokens_input + tokens_output + tokens_reasoning), 0), COALESCE(SUM(cost), 0)
        FROM session
        WHERE time_updated >= ?
    """, (week_start,))
    week = cursor.fetchone()
    
    # All time stats
    cursor.execute("""
        SELECT COUNT(*), COALESCE(SUM(tokens_input + tokens_output + tokens_reasoning), 0), COALESCE(SUM(cost), 0)
        FROM session
    """)
    total = cursor.fetchone()
    
    conn.close()
    
    return {
        "today": {
            "sessions": today[0],
            "tokens": today[1],
            "cost": today[2]
        },
        "week": {
            "sessions": week[0],
            "tokens": week[1],
            "cost": week[2]
        },
        "total": {
            "sessions": total[0],
            "tokens": total[1],
            "cost": total[2]
        }
    }

def main():
    db_path = get_db_path()
    
    if not db_path.exists():
        print(json.dumps({"ok": False, "error": "OpenCode database not found"}))
        sys.exit(1)
    
    try:
        sessions = get_sessions(db_path)
        models = get_models(db_path)
        available_models = get_available_models()
        stats = get_stats(db_path)
        
        # Get last used model
        last_model = models[0] if models else None
        
        record = {
            "ok": True,
            "sessions": sessions,
            "models": models,
            "available_models": available_models,
            "last_model": last_model,
            "stats": stats,
            "time_updated": int(datetime.now().timestamp() * 1000)
        }
        
        print(json.dumps(record, ensure_ascii=False))
        
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}))
        sys.exit(1)

if __name__ == "__main__":
    main()
