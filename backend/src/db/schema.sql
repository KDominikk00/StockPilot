CREATE TABLE IF NOT EXISTS companies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ticker TEXT NOT NULL UNIQUE,
  isin TEXT NOT NULL UNIQUE,
  name_full TEXT NOT NULL,
  aliases_json TEXT NOT NULL DEFAULT '[]',
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE IF NOT EXISTS announcements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id INTEGER REFERENCES companies(id),
  external_id TEXT NOT NULL UNIQUE,
  source TEXT NOT NULL,
  title TEXT NOT NULL,
  raw_text TEXT,
  url TEXT NOT NULL,
  published_at TEXT NOT NULL,
  match_confidence TEXT NOT NULL,
  matched_name TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_announcements_company_id ON announcements(company_id);
CREATE INDEX IF NOT EXISTS idx_announcements_published_at ON announcements(published_at);

CREATE TABLE IF NOT EXISTS calendar_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id INTEGER REFERENCES companies(id),
  external_id TEXT NOT NULL UNIQUE,
  event_type TEXT NOT NULL,
  report_period TEXT,
  event_date TEXT NOT NULL,
  source_text TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_calendar_events_company_id ON calendar_events(company_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_event_date ON calendar_events(event_date);

CREATE TABLE IF NOT EXISTS device_subscriptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_token TEXT NOT NULL UNIQUE,
  last_seen_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE IF NOT EXISTS device_subscription_tickers (
  device_subscription_id INTEGER NOT NULL REFERENCES device_subscriptions(id),
  ticker TEXT NOT NULL,
  PRIMARY KEY (device_subscription_id, ticker)
);

CREATE INDEX IF NOT EXISTS idx_device_subscription_tickers_ticker ON device_subscription_tickers(ticker);

CREATE TABLE IF NOT EXISTS feed_poll_state (
  feed_url TEXT PRIMARY KEY,
  last_item_guid TEXT,
  last_fetched_at TEXT
);

CREATE TABLE IF NOT EXISTS unmatched_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source TEXT NOT NULL,
  raw_name TEXT NOT NULL,
  external_id TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
