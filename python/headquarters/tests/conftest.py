"""운영 DB 대신 임시 디렉터리의 독립 MySQL을 사용한다. 소켓만 열고 TCP는 끈다."""
from __future__ import annotations

import os
import shutil
import subprocess
import time
from pathlib import Path
from dataclasses import replace
import pymysql
import pytest
from fastapi.testclient import TestClient
from python.headquarters.config import get_settings
from python.headquarters.main import app
from python.headquarters import login
from python.headquarters import database, firebase

SCHEMA = '''
CREATE TABLE customer (customer_id VARCHAR(254) PRIMARY KEY, age INT, totalprice DECIMAL(15,2));
CREATE TABLE product (p_code INT PRIMARY KEY, p_name VARCHAR(100), b_name VARCHAR(100));
CREATE TABLE purchase (customer_customer_id VARCHAR(254), p_code INT, p_price DECIMAL(15,2), p_date DATETIME);
CREATE TABLE review (customer_customer_id VARCHAR(254), product_p_code INT, review_seq INT, r_date DATETIME,
 context TEXT, r_fit VARCHAR(45), rating FLOAT, likecount INT, PRIMARY KEY(customer_customer_id,product_p_code,review_seq));
CREATE TABLE contact (customer_customer_id VARCHAR(254), head_office_id INT, c_seq INT, contact_post TEXT,
 c_date DATETIME, c_answer VARCHAR(45), c_answerdate DATETIME, c_status TINYINT,
 PRIMARY KEY(customer_customer_id,head_office_id,c_seq));
CREATE TABLE authorized_dealer (seq INT PRIMARY KEY);
CREATE TABLE notice (head_office_id INT, authorized_dealer_seq INT, seq INT, category VARCHAR(45),
 title VARCHAR(100), content TEXT, savedate DATETIME);
'''


@pytest.fixture(scope='session')
def mysql_server(tmp_path_factory):
    binary = shutil.which('mysqld')
    if not binary:
        pytest.skip('실제 MySQL 통합 테스트: mysqld가 필요합니다.')
    directory = tmp_path_factory.mktemp('hq_mysql')
    datadir = directory / 'data'
    sock = '/tmp/hq-test-' + str(os.getpid()) + '.sock'
    init = subprocess.run([binary, '--no-defaults', '--initialize-insecure', '--datadir=' + str(datadir)],
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
    assert init.returncode == 0, init.stdout.decode()
    logfile = (directory / 'server.log').open('w')
    process = subprocess.Popen([binary, '--no-defaults', '--datadir=' + str(datadir), '--socket=' + sock,
                                '--skip-networking', '--mysqlx=OFF', '--pid-file=' + str(directory / 'mysql.pid')],
                               stdout=logfile, stderr=subprocess.STDOUT)
    try:
        for _ in range(150):
            if process.poll() is not None:
                raise RuntimeError((directory / 'server.log').read_text())
            try:
                conn = pymysql.connect(unix_socket=sock, user='root', autocommit=True)
                break
            except pymysql.MySQLError:
                time.sleep(.1)
        else:
            raise RuntimeError('임시 MySQL 시작 시간 초과')
        with conn:
            with conn.cursor() as cur:
                cur.execute('CREATE DATABASE hq_test CHARACTER SET utf8mb4')
                cur.execute('USE hq_test')
                migration = (Path(__file__).resolve().parents[1] / 'migrations' / '001_admin_metadata.sql').read_text()
                for sql in (SCHEMA + migration).split(';'):
                    if sql.strip():
                        cur.execute(sql)
        yield replace(get_settings(), db_host='', db_socket=sock, db_user='root', db_password='', db_name='hq_test')
    finally:
        process.terminate()
        process.wait(timeout=30)
        logfile.close()


@pytest.fixture
def client(mysql_server, monkeypatch):
    monkeypatch.setattr(database, 'get_settings', lambda: mysql_server)
    monkeypatch.setattr('python.headquarters.check_database.get_settings', lambda: mysql_server)
    admin = {'uid': 'admin-uid', 'employee_id': 'HQ01', 'head_office_id': 1, 'role': 'headquarters'}
    app.dependency_overrides[login.current_admin] = lambda: admin
    monkeypatch.setattr(firebase, 'profiles', lambda emails: {e: {'name': '김민수', 'email': e} for e in emails})
    monkeypatch.setattr(firebase, 'find_emails', lambda prefix: ['member@example.com'] if prefix == '김' else [])
    with database.connection() as conn, conn.cursor() as cur:
        for table in ['hq_audit_log', 'hq_member_metadata', 'hq_review_moderation', 'review', 'contact',
                      'purchase', 'product', 'customer', 'authorized_dealer', 'notice']:
            cur.execute('DELETE FROM ' + table)
        cur.execute("INSERT INTO customer VALUES ('member@example.com',25,300),('other@example.com',30,0)")
        cur.execute("INSERT INTO product VALUES (1,'나이키 운동화','나이키')")
        cur.execute("INSERT INTO purchase VALUES ('member@example.com',1,100,'2026-09-30 23:59:59'),"
                    "('member@example.com',1,200,'2026-10-01 00:00:00'),('member@example.com',1,999,'2026-10-02 00:00:00')")
        cur.execute("INSERT INTO review VALUES ('member@example.com',1,1,'2026-10-01','리뷰1','정사이즈',5,0),"
                    "('member@example.com',1,2,'2026-10-01','리뷰2','정사이즈',4,0)")
        cur.execute("INSERT INTO contact VALUES ('member@example.com',1,1,'배송 문의','2026-10-01',NULL,NULL,0),"
                    "('member@example.com',2,1,'사이즈 문의','2026-10-01',NULL,NULL,0)")
        conn.commit()
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
