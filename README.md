# FastAPI 7주차 실습 서버

배포한 앱이 없는 경우 이 서버를 개인 EC2에 띄워 CORS·HTTPS 공통 실습에 합류한다. `GET /health`가 `{"status":"ok"}`를 반환하는 앱이며 DB·로그인·Docker는 사용하지 않는다. 처음에는 CORS를 설정하지 않는다.

이미 배포한 앱이 있다면 이 서버를 추가로 실행하지 않고 기존 앱을 사용해도 된다. 기존 Nginx 사이트와 인증서가 있다면 그 설정을 확인하고 재사용한다. 아래 기본 포트는 8000이다. 다른 포트를 쓰면 SSH 터널과 Nginx의 upstream 포트도 함께 맞춘다.

## 1. 개인 EC2에서 실행하기

개인 Ubuntu EC2에 SSH로 접속한 터미널에서 진행한다. EC2 생성과 접속은 [공통 실습 자료](https://app.notion.com/p/421df97f0257816bb348c9488409cd1d)의 1절에서 새 앱 경로를 따른다. 공통 자료의 2~4절과 이 README의 1~2절은 같은 앱을 준비하는 과정이므로 한쪽만 따라 한다.

```bash
sudo apt update
sudo apt install -y curl git dnsutils snapd
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
uv python install 3.12

git clone https://github.com/WaffleStudio24-5/fastapi-lab-7.git
cd fastapi-lab-7
uv sync --frozen
uv run --frozen uvicorn main:app --host 127.0.0.1 --port 8000
```

다른 SSH 터미널에서 확인한다.

```bash
curl -i http://127.0.0.1:8000/health
```

`200 OK`와 `{"status":"ok"}`가 나와야 한다. `/docs`와 `/openapi.json`도 제공한다. EC2의 8000 포트는 인터넷에 열지 않는다. 브라우저 실습에서는 공통 자료의 SSH 터널을 사용하고, 이후 Nginx를 통해 접속한다.

## 2. SSH를 끊어도 실행되게 하기

앞에서 실행한 서버를 `Ctrl+C`로 종료하고, 프로젝트 폴더에서 개인 실습용 서비스를 등록한다.

```bash
LAB_PROJECT_DIR=$(pwd)
sudo tee /etc/systemd/system/fastapi-lab-7.service > /dev/null <<SERVICE
[Unit]
Description=FastAPI Lab 7
Wants=network-online.target
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$LAB_PROJECT_DIR
ExecStart=$LAB_PROJECT_DIR/.venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000 --proxy-headers --forwarded-allow-ips 127.0.0.1
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable --now fastapi-lab-7
sudo systemctl status fastapi-lab-7 --no-pager
curl -i http://127.0.0.1:8000/health
```

코드를 수정한 뒤에는 `sudo systemctl restart fastapi-lab-7`로 반영한다. 오류는 `sudo journalctl -u fastapi-lab-7 -n 50 --no-pager`로 확인한다.

## 3. CORS 실패와 preflight 확인하기

공통 실습 자료의 5-1절을 따라 내 컴퓨터에 확인용 페이지와 SSH 터널을 준비한다. `http://localhost:5500` 페이지에서 개발자 도구를 연다. SSH 터널이 로컬 18000을 EC2의 `127.0.0.1:8000`에 연결한 상태에서 실행한다.

```js
fetch('http://127.0.0.1:18000/health', {
  headers: { Authorization: 'Bearer seminar7-demo' }
})
  .then(async response => console.log(response.status, await response.json()))
  .catch(console.error);
```

`Authorization` 헤더 때문에 브라우저가 먼저 `OPTIONS` preflight를 보낸다. 초기 앱에는 CORS 설정이 없어 응답 읽기에 실패한다. 이 앱은 토큰을 검증하지 않으며, 위 헤더는 preflight를 관찰하기 위한 예시다.

`main.py`에 다음 import를 추가하고, `app = FastAPI()` 바로 아래에 미들웨어를 등록한다.

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5500"],
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["Authorization"],
)
```

서비스를 재시작한 뒤 같은 브라우저 요청을 반복한다. preflight가 성공하고 `200`과 `{"status":"ok"}`를 읽을 수 있어야 한다. 터미널의 curl만으로는 브라우저의 CORS 동작을 확인할 수 없다.

## 4. 공통 HTTPS 실습에 합류하기

공통 자료의 6~8절에서 도메인 발급·DNS·Nginx·Certbot 단계를 진행한다. 이 저장소를 쓰면 앱 경로는 다음과 같다.

| 항목 | 이 저장소에서 사용할 값 |
| --- | --- |
| 실행 대상 | `main:app` |
| 서비스 이름 | `fastapi-lab-7` |
| 확인할 API | `/health` |
| 문서 | `/docs`, `/openapi.json` |
| Nginx upstream | `http://127.0.0.1:8000` |

공통 CORS 확인과 HTTPS 확인에는 위의 `/health` 요청을 사용한다. 회원가입·로그인·DB 설정은 생략한다. Nginx는 `location /`에서 경로를 보존해 전달하며, 앱에 `/api` 접두사나 `--root-path /api`를 추가하지 않는다.

완료 후 `https://자신의도메인/health`에서 인증서 경고 없이 `200`과 JSON을 확인한다. 같은 주소의 `/docs`에서도 요청해 본다. HTTPS 적용과 별도 프론트 origin의 CORS 허용은 각각 확인한다.

기존 배포 서버를 사용했다면 공통 자료 마지막의 서비스 종료·EC2 정리 명령을 그대로 실행하지 않는다. 이번에 만든 개인 실습 자원만 정리한다.

이 README로 새로 등록한 서비스만 멈추려면 다음을 실행한다.

```bash
sudo systemctl disable --now fastapi-lab-7
```

참고: [FastAPI CORS](https://fastapi.tiangolo.com/tutorial/cors/), [uv 프로젝트 실행](https://docs.astral.sh/uv/guides/projects/), [Uvicorn 설정](https://uvicorn.dev/settings/)
