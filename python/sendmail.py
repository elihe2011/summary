#!/usr/bin/python3

import time
import requests
import smtplib
from email.mime.text import MIMEText
from email.header import Header


def get_public_ip():
    ip = ""
    now = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())

    try:
        ip = requests.get('http://ifconfig.me/ip', timeout=1).text.strip()
        print('[%s] obtain public ip address: %s' % (now, ip))
    except Exception as e:
        print('[%s] obtain public ip address failed: %s' % (now, e))

    return ip


def send_email(ip):
    mail_server="smtp.sina.com"
    mail_user="***@sina.com"
    mail_pass="***"

    sender = '***@sina.com'
    receivers = ['***@live.cn']

    message = MIMEText('IP: %s' % ip, 'plain', 'utf-8')
    message['Subject'] = Header('IP address notification')
    message['From'] = Header(sender)
    message['To'] =  Header(receivers[0])

    now = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())

    try:
        smtpObj = smtplib.SMTP()
        smtpObj.connect(mail_server)
        smtpObj.login(mail_user, mail_pass)
        smtpObj.sendmail(sender, receivers, message.as_string())
        print('[%s] email sent successfully' % now)
    except smtplib.SMTPException as e:
        print('[%s] email sending failed: %s' % (now, e))
    finally:
        smtpObj.quit()


if __name__ == '__main__':
    ip = get_public_ip()

    if ip != '':
        send_email(ip)
