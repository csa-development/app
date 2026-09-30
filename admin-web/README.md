# CSA Admin Web

This admin web app now connects to your Django backend so you can:

- sign in with a Django staff or superuser account
- publish alerts and breaking news
- upload images for news content
- view user statistics and login activity
- monitor incident reports and update their status

## Backend routes used

- `POST /api/admin/login/`
- `GET /api/admin/dashboard/`
- `GET /api/admin/users/`
- `GET /api/content/admin/news/`
- `POST /api/content/admin/news/`
- `PUT /api/content/admin/news/<id>/`
- `DELETE /api/content/admin/news/<id>/`
- `GET /api/incidents/admin/reports/`
- `PATCH /api/incidents/admin/reports/<reference_number>/`

## First time setup

If you do not already have an admin account:

```powershell
cd C:\Users\user\Desktop\startiing-flutter\csa_backend\csa_project
.\..\venv\Scripts\python.exe manage.py createsuperuser
```

## Run the backend

```powershell
cd C:\Users\user\Desktop\startiing-flutter\csa_backend\csa_project
.\..\venv\Scripts\python.exe manage.py runserver
```

## Run the admin web app

```powershell
cd C:\Users\user\Desktop\startiing-flutter\admin-web
Copy-Item .env.example .env
npm install
npm run dev
```

Open:

`http://localhost:5173`

## How the mobile app connects

If your mobile emulator is using this same Django backend, the admin dashboard will reflect backend changes:

- OTP logins from the mobile app are now recorded for dashboard statistics
- published alerts and breaking news use the same database the mobile app reads from
- incident reports shown in the admin panel come from the shared backend database

So the React admin and the mobile app stay in sync through Django.
