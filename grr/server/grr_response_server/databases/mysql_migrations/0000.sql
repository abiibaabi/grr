CREATE TABLE IF NOT EXISTS artifacts(
    name VARCHAR(100) PRIMARY KEY,
    definition MEDIUMBLOB
);

CREATE TABLE IF NOT EXISTS blobs(
    blob_id BINARY(32),
    chunk_index INT UNSIGNED,
    blob_chunk MEDIUMBLOB,
    PRIMARY KEY (blob_id, chunk_index)
);

CREATE TABLE IF NOT EXISTS hash_blob_references(
    hash_id BINARY(32) PRIMARY KEY,
    blob_references MEDIUMBLOB
);

CREATE TABLE IF NOT EXISTS clients(
    client_id BIGINT UNSIGNED PRIMARY KEY,
    last_snapshot_timestamp TIMESTAMP(6) NULL DEFAULT NULL,
    last_startup_timestamp TIMESTAMP(6) NULL DEFAULT NULL,
    last_crash_timestamp TIMESTAMP(6) NULL DEFAULT NULL,
    fleetspeak_enabled BOOL,
    certificate BLOB,
    last_ping TIMESTAMP(6) NULL DEFAULT NULL,
    last_clock TIMESTAMP(6) NULL DEFAULT NULL,
    last_ip MEDIUMBLOB,
    last_foreman TIMESTAMP(6) NULL DEFAULT NULL,
    first_seen TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    last_version_string VARCHAR(128),
    last_platform VARCHAR(128),
    last_platform_release VARCHAR(256)
);

CREATE TABLE IF NOT EXISTS client_labels(
    client_id BIGINT UNSIGNED,
    owner_username_hash BINARY(32),
    label VARCHAR(100),
    owner_username VARCHAR(254),
    PRIMARY KEY (client_id, owner_username_hash, label),
    -- TODO: Add FOREIGN KEY when owner does not use `GRR` anymore.
    FOREIGN KEY (client_id)
        REFERENCES clients(client_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS owner_label_idx
    ON client_labels(owner_username(191), label);

CREATE TABLE IF NOT EXISTS client_snapshot_history(
    client_id BIGINT UNSIGNED,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    client_snapshot MEDIUMBLOB,
    PRIMARY KEY (client_id, timestamp),
    FOREIGN KEY (client_id)
        REFERENCES clients(client_id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS client_startup_history(
    client_id BIGINT UNSIGNED,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    startup_info MEDIUMBLOB,
    PRIMARY KEY (client_id, timestamp),
    FOREIGN KEY (client_id)
        REFERENCES clients(client_id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS client_crash_history(
    client_id BIGINT UNSIGNED,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    crash_info MEDIUMBLOB,
    PRIMARY KEY (client_id, timestamp),
    FOREIGN KEY (client_id)
        REFERENCES clients(client_id)
        ON DELETE CASCADE
);

ALTER TABLE clients
    ADD FOREIGN KEY (client_id, last_snapshot_timestamp)
    REFERENCES client_snapshot_history(client_id, timestamp);

ALTER TABLE clients
    ADD FOREIGN KEY (client_id, last_startup_timestamp)
    REFERENCES client_startup_history(client_id, timestamp);

ALTER TABLE clients
    ADD FOREIGN KEY (client_id, last_crash_timestamp)
    REFERENCES client_crash_history(client_id, timestamp);

CREATE TABLE IF NOT EXISTS client_keywords(
    client_id BIGINT UNSIGNED,
    keyword_hash BINARY(32),
    keyword VARCHAR(255),
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    PRIMARY KEY (client_id, keyword_hash),
    FOREIGN KEY (client_id)
        REFERENCES clients(client_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS client_index_by_keyword_hash
    ON client_keywords(keyword_hash);

CREATE TABLE IF NOT EXISTS client_stats(
    client_id BIGINT UNSIGNED,
    payload MEDIUMBLOB,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    -- Timestamp is the first part of the primary key, because both
    -- ReadClientStats and DeleteOldClientStats filter by timestamp, but only
    -- ReadClientStats filters by client_id.
    PRIMARY KEY (timestamp, client_id),
    FOREIGN KEY (client_id)
        REFERENCES clients(client_id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS client_report_graphs(
    client_label VARCHAR(100) NOT NULL,
    report_type INT UNSIGNED NOT NULL,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    graph_series MEDIUMBLOB NOT NULL,
    PRIMARY KEY (client_label, report_type, timestamp)
);

CREATE TABLE IF NOT EXISTS grr_users(
    username_hash BINARY(32) PRIMARY KEY,
    username VARCHAR(254),
    password VARBINARY(255),
    ui_mode INT UNSIGNED,
    canary_mode BOOL,
    user_type INT UNSIGNED
);

CREATE INDEX IF NOT EXISTS username_idx ON grr_users(username(191));

CREATE TABLE IF NOT EXISTS approval_request(
    username_hash BINARY(32),
    approval_type INT UNSIGNED,
    subject_id VARCHAR(128),
    approval_id BIGINT UNSIGNED,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    expiration_time TIMESTAMP(6) NOT NULL DEFAULT 0,
    approval_request MEDIUMBLOB,
    PRIMARY KEY (username_hash, approval_id),
    FOREIGN KEY (username_hash)
        REFERENCES grr_users (username_hash)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS by_username_type_subject
    ON approval_request(username_hash, approval_type, subject_id);

CREATE TABLE IF NOT EXISTS approval_grant(
    username_hash BINARY(32),
    approval_id BIGINT UNSIGNED,
    grantor_username_hash BINARY(32),
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    PRIMARY KEY (username_hash, approval_id, grantor_username_hash, timestamp),
    FOREIGN KEY (username_hash, approval_id)
        REFERENCES approval_request (username_hash, approval_id)
        ON DELETE CASCADE,
    FOREIGN KEY (username_hash)
        REFERENCES grr_users (username_hash)
        ON DELETE CASCADE,
    FOREIGN KEY (grantor_username_hash)
        REFERENCES grr_users (username_hash)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS user_notification(
    username_hash BINARY(32),
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    notification_state INT UNSIGNED,
    notification MEDIUMBLOB,
    PRIMARY KEY (username_hash, timestamp),
    FOREIGN KEY (username_hash)
        REFERENCES grr_users (username_hash)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS api_audit_entry(
    -- Entries are retained after user deletion. Thus, do not use a FOREIGN KEY
    -- to grr_users.username_hash.
    username VARCHAR(254),
    router_method_name VARCHAR(128),
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    details MEDIUMBLOB,
    PRIMARY KEY (username(191), timestamp)
);

CREATE INDEX IF NOT EXISTS timestamp_idx
    ON api_audit_entry(timestamp);

CREATE INDEX IF NOT EXISTS router_method_name_idx
    ON api_audit_entry(router_method_name);

CREATE TABLE IF NOT EXISTS message_handler_requests(
    handlername VARCHAR(128),
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    request_id INT UNSIGNED,
    request MEDIUMBLOB,
    leased_until TIMESTAMP(6) NULL DEFAULT NULL,
    leased_by VARCHAR(128),
    PRIMARY KEY (request_id)
);

CREATE INDEX IF NOT EXISTS message_handler_requests_by_lease
    ON message_handler_requests(leased_until, leased_by);

CREATE TABLE IF NOT EXISTS foreman_rules(
    hunt_id VARCHAR(128),
    expiration_time TIMESTAMP(6) NOT NULL DEFAULT 0,
    rule MEDIUMBLOB,
    PRIMARY KEY (hunt_id)
);

CREATE TABLE IF NOT EXISTS cron_jobs(
    job_id VARCHAR(100),
    job MEDIUMBLOB,
    create_time TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    current_run_id INT UNSIGNED,
    enabled BOOL,
    forced_run_requested BOOL,
    last_run_time TIMESTAMP(6) NULL DEFAULT NULL,
    last_run_status INT UNSIGNED,
    state MEDIUMBLOB,
    leased_until TIMESTAMP(6) NULL DEFAULT NULL,
    leased_by VARCHAR(128),
    PRIMARY KEY (job_id)
);

CREATE INDEX IF NOT EXISTS cron_jobs_by_lease
    ON cron_jobs(leased_until, leased_by);

CREATE TABLE IF NOT EXISTS cron_job_runs(
    job_id VARCHAR(100),
    run_id INT UNSIGNED,
    write_time TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    run MEDIUMBLOB,
    PRIMARY KEY (job_id, run_id),
    FOREIGN KEY (job_id) REFERENCES cron_jobs (job_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS client_messages(
    client_id BIGINT UNSIGNED,
    message_id BIGINT UNSIGNED,
    timestamp DATETIME(6),
    message MEDIUMBLOB,
    leased_until DATETIME(6),
    leased_by VARCHAR(128),
    leased_count INT DEFAULT 0,
    PRIMARY KEY (client_id, message_id),
    FOREIGN KEY (client_id)
        REFERENCES clients(client_id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS flows(
    client_id BIGINT UNSIGNED,
    flow_id BIGINT UNSIGNED,
    long_flow_id VARCHAR(255),
    parent_flow_id BIGINT UNSIGNED,
    parent_hunt_id BIGINT UNSIGNED,
    flow BLOB,
    flow_state INT UNSIGNED,
    client_crash_info MEDIUMBLOB,
    next_request_to_process INT UNSIGNED,
    pending_termination MEDIUMBLOB,
    processing_deadline TIMESTAMP(6) NULL DEFAULT NULL,
    processing_on VARCHAR(128),
    processing_since TIMESTAMP(6) NULL DEFAULT NULL,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    network_bytes_sent BIGINT UNSIGNED,
    user_cpu_time_used_micros BIGINT UNSIGNED,
    system_cpu_time_used_micros BIGINT UNSIGNED,
    num_replies_sent BIGINT UNSIGNED,
    last_update TIMESTAMP(6) NOT NULL DEFAULT NOW(6) ON UPDATE NOW(6),
    PRIMARY KEY (client_id, flow_id),
    FOREIGN KEY (client_id)
        REFERENCES clients(client_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS timestamp_idx ON flows(timestamp);

CREATE INDEX IF NOT EXISTS flows_by_hunt ON flows(parent_hunt_id);

CREATE TABLE IF NOT EXISTS flow_requests(
    client_id BIGINT UNSIGNED,
    flow_id BIGINT UNSIGNED,
    request_id BIGINT UNSIGNED,
    needs_processing BOOL NOT NULL DEFAULT FALSE,
    responses_expected BIGINT UNSIGNED,
    request MEDIUMBLOB,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    PRIMARY KEY (client_id, flow_id, request_id),
    FOREIGN KEY (client_id)
        REFERENCES clients(client_id)
        ON DELETE CASCADE,
    FOREIGN KEY (client_id, flow_id)
        REFERENCES flows(client_id, flow_id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS flow_responses(
    client_id BIGINT UNSIGNED,
    flow_id BIGINT UNSIGNED,
    request_id BIGINT UNSIGNED,
    response_id BIGINT UNSIGNED,
    response MEDIUMBLOB,
    status MEDIUMBLOB,
    iterator MEDIUMBLOB,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    PRIMARY KEY (client_id, flow_id, request_id, response_id),
    FOREIGN KEY (client_id)
        REFERENCES clients(client_id)
        ON DELETE CASCADE,
    FOREIGN KEY (client_id, flow_id, request_id)
        REFERENCES flow_requests(client_id, flow_id, request_id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS flow_processing_requests(
    client_id BIGINT UNSIGNED,
    flow_id BIGINT UNSIGNED,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    request MEDIUMBLOB,
    delivery_time TIMESTAMP(6) NULL DEFAULT NULL,
    leased_until TIMESTAMP(6) NULL DEFAULT NULL,
    leased_by VARCHAR(128),
    PRIMARY KEY (client_id, flow_id, timestamp),
    FOREIGN KEY (client_id)
        REFERENCES clients(client_id)
        ON DELETE CASCADE,
    FOREIGN KEY (client_id, flow_id)
        REFERENCES flows(client_id, flow_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS flow_processing_requests_by_lease
    ON flow_processing_requests(leased_until, leased_by);

CREATE TABLE IF NOT EXISTS flow_results(
    client_id BIGINT UNSIGNED,
    flow_id BIGINT UNSIGNED,
    hunt_id BIGINT UNSIGNED,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    payload MEDIUMBLOB,
    type VARCHAR(128),
    tag VARCHAR(128),
    PRIMARY KEY (client_id, flow_id, timestamp),
    FOREIGN KEY (client_id)
        REFERENCES clients(client_id)
        ON DELETE CASCADE,
    FOREIGN KEY (client_id, flow_id)
        REFERENCES flows(client_id, flow_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS flow_results_hunt_id_flow_id_timestamp
    ON flow_results(hunt_id, flow_id, timestamp);

CREATE INDEX IF NOT EXISTS flow_results_hunt_id_flow_id_type_tag_timestamp
    ON flow_results(hunt_id, flow_id, type, tag, timestamp);

CREATE TABLE IF NOT EXISTS flow_log_entries(
    log_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    client_id BIGINT UNSIGNED,
    flow_id BIGINT UNSIGNED,
    hunt_id BIGINT UNSIGNED,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    message MEDIUMBLOB,
    PRIMARY KEY (log_id),
    FOREIGN KEY (client_id)
        REFERENCES clients(client_id)
        ON DELETE CASCADE,
    FOREIGN KEY (client_id, flow_id)
        REFERENCES flows(client_id, flow_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS flow_log_entries_by_flow
    ON flow_log_entries(client_id, flow_id, log_id);

CREATE INDEX IF NOT EXISTS flow_log_entries_by_hunt
    ON flow_log_entries(hunt_id, flow_id, log_id);

CREATE TABLE IF NOT EXISTS flow_output_plugin_log_entries(
    log_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    client_id BIGINT UNSIGNED,
    flow_id BIGINT UNSIGNED,
    hunt_id BIGINT UNSIGNED,
    output_plugin_id BIGINT UNSIGNED,
    log_entry_type INT UNSIGNED,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    message MEDIUMBLOB,
    PRIMARY KEY (log_id),
    FOREIGN KEY (client_id)
        REFERENCES clients(client_id)
        ON DELETE CASCADE,
    FOREIGN KEY (client_id, flow_id)
        REFERENCES flows(client_id, flow_id)
        ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS flow_output_plugin_log_entries_by_flow
    ON flow_output_plugin_log_entries(
        client_id, flow_id, output_plugin_id, log_entry_type, log_id);

CREATE UNIQUE INDEX IF NOT EXISTS flow_output_plugin_log_entries_by_hunt
    ON flow_output_plugin_log_entries(
        hunt_id, output_plugin_id, log_entry_type, log_id);

CREATE TABLE IF NOT EXISTS signed_binary_references(
    binary_type INT UNSIGNED NOT NULL,
    binary_path_hash BINARY(32) NOT NULL,
    binary_path TEXT NOT NULL,
    blob_references MEDIUMBLOB NOT NULL,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6) ON UPDATE NOW(6),
    PRIMARY KEY (binary_type, binary_path_hash)
);

CREATE TABLE IF NOT EXISTS client_paths(
    client_id BIGINT UNSIGNED NOT NULL,
    path_type INT UNSIGNED NOT NULL,
    path_id BINARY(32) NOT NULL,
    path TEXT NOT NULL,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    last_stat_entry_timestamp TIMESTAMP(6) NULL DEFAULT NULL,
    last_hash_entry_timestamp TIMESTAMP(6) NULL DEFAULT NULL,
    directory BOOLEAN NOT NULL DEFAULT FALSE,
    depth INT UNSIGNED NOT NULL,
    PRIMARY KEY (client_id, path_type, path_id),
    FOREIGN KEY (client_id) REFERENCES clients(client_id) ON DELETE CASCADE,
    CHECK (depth = length(path) - length(replace(path, '/', '')))
);

CREATE INDEX IF NOT EXISTS client_paths_idx
    ON client_paths(client_id, path_type, path(128));

CREATE TABLE IF NOT EXISTS client_path_stat_entries(
    client_id BIGINT UNSIGNED NOT NULL,
    path_type INT UNSIGNED NOT NULL,
    path_id BINARY(32) NOT NULL,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    stat_entry MEDIUMBLOB NOT NULL,
    PRIMARY KEY (client_id, path_type, path_id, timestamp),
    FOREIGN KEY (client_id, path_type, path_id)
    REFERENCES client_paths(client_id, path_type, path_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS client_path_hash_entries(
    client_id BIGINT UNSIGNED NOT NULL,
    path_type INT UNSIGNED NOT NULL,
    path_id BINARY(32) NOT NULL,
    timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    hash_entry MEDIUMBLOB NOT NULL,
    sha256 BINARY(32) NOT NULL,
    PRIMARY KEY (client_id, path_type, path_id, timestamp),
    FOREIGN KEY (client_id, path_type, path_id)
    REFERENCES client_paths(client_id, path_type, path_id) ON DELETE CASCADE
);

ALTER TABLE client_paths
    ADD FOREIGN KEY (client_id, path_type, path_id, last_stat_entry_timestamp)
    REFERENCES client_path_stat_entries(client_id, path_type, path_id, timestamp);

ALTER TABLE client_paths
    ADD FOREIGN KEY (client_id, path_type, path_id, last_hash_entry_timestamp)
    REFERENCES client_path_hash_entries(client_id, path_type, path_id, timestamp);

CREATE TABLE IF NOT EXISTS hunts(
    hunt_id BIGINT UNSIGNED NOT NULL,
    create_timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    last_update_timestamp TIMESTAMP(6) NOT NULL DEFAULT NOW(6),
    creator VARCHAR(128),
    init_start_time TIMESTAMP(6) NULL DEFAULT NULL,
    last_start_time TIMESTAMP(6) NULL DEFAULT NULL,
    duration_micros BIGINT NOT NULL,
    client_rate FLOAT,
    client_limit INT UNSIGNED,
    num_clients_at_start_time INT UNSIGNED,
    hunt_state INT UNSIGNED,
    hunt_state_comment TEXT,
    description TEXT,
    hunt MEDIUMBLOB NOT NULL,
    PRIMARY KEY (hunt_id)
);

CREATE TABLE IF NOT EXISTS hunt_output_plugins_states(
    hunt_id BIGINT UNSIGNED NOT NULL,
    plugin_id BIGINT UNSIGNED NOT NULL,
    plugin_name VARCHAR(128),
    plugin_args MEDIUMBLOB,
    plugin_state MEDIUMBLOB,
    PRIMARY KEY (hunt_id, plugin_id),
    FOREIGN KEY (hunt_id)
        REFERENCES hunts(hunt_id)
        ON DELETE CASCADE
);
