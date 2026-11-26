# FastAPI 7주차 실습 서버

각자 사용 중인 EC2에 이 앱을 띄우고 **HTTPS 연결 → CORS 확인** 순서로 실습한다. `GET /health`가 `{"status":"ok"}`를 반환하며 처음에는 CORS를 설정하지 않는다. DB·로그인·Docker는 사용하지 않는다.

전체 절차와 도메인 발급 화면은 [노션 실습 자료](https://app.notion.com/p/421df97f0257816bb348c9488409cd1d)에 있다.

## 1. EC2에서 앱 실행하기

Ubuntu EC2에 접속한 터미널에서 시작한다. Python 3.12·uv·tmux를 사용한다. 80·443·8000 포트를 확인하고 기존 서비스와 충돌하지 않게 한다.

```bash
git clone https://github.com/WaffleStudio24-5/fastapi-lab-7.git
cd fastapi-lab-7
tmux new -s fastapi-lab-7
uv sync --frozen --python 3.12
uv run --frozen uvicorn main:app --host 127.0.0.1 --port 8000
```

같은 EC2의 다른 터미널에서 확인한다.

```bash
curl -i http://127.0.0.1:8000/health
```

`200 OK`와 `{"status":"ok"}`가 나와야 한다. `/docs`와 `/openapi.json`도 제공한다. 앱의 8000번은 인터넷에 열지 않는다.

## 2. HTTPS 연결하기

노션 자료의 **2~4절**을 따라 도메인·Nginx·Certbot을 설정한다. Nginx는 `http://127.0.0.1:8000`으로 원래 경로를 전달한다.

브라우저 주소창에서 `https://자신의도메인/health`를 열어 인증서 경고 없이 JSON이 보이는지 확인한다. HTTPS로 배포한 프론트에서 요청하므로 API에도 HTTPS가 먼저 필요하다.

## 3. 배포된 프론트에서 CORS 확인하기

[CORS 실습 페이지](https://wafflestudio24-5.github.io/fastapi-lab-7/)에 자신의 HTTPS API 주소를 입력한다. **GET 요청**, **Authorization 헤더로 요청** 버튼을 눌러 본다. CORS 설정 전에는 응답 읽기에 실패한다. 로컬 페이지 서버나 SSH 터널은 필요 없다.

`main.py`에 import를 추가하고 `app = FastAPI()` 아래에 미들웨어를 등록한다.

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://wafflestudio24-5.github.io"],
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["Authorization"],
)
```

허용할 값은 프론트의 **origin**이다. `/fastapi-lab-7/` 경로와 마지막 `/`는 넣지 않는다.

앱을 실행한 tmux 창에서 `Ctrl+C`로 종료한 뒤 다시 실행한다.

```bash
uv run --frozen uvicorn main:app --host 127.0.0.1 --port 8000
```

같은 버튼을 다시 눌러 두 요청 모두 `HTTP 200`과 JSON이 보이는지 확인한다. 두 번째 요청에만 실습용 Authorization 헤더가 붙으며 이 앱은 토큰을 검사하지 않는다. Network 탭에서 OPTIONS와 GET도 구분해 볼 수 있다.

실습을 마치면 앱의 tmux 창에서 `Ctrl+C`로 종료한다.

참고: [FastAPI CORS](https://fastapi.tiangolo.com/tutorial/cors/), [MDN Mixed content](https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Mixed_content)
