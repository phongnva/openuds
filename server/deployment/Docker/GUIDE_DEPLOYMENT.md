# Hướng Dẫn Triển Khai và Cấu Hình Bảo Mật OpenUDS

Tài liệu này hướng dẫn chi tiết quy trình từ lúc clone mã nguồn đến khi hoàn thiện triển khai hệ thống OpenUDS với các cấu hình bảo mật nâng cao (Security Headers, CSP) sử dụng Podman/Docker.

## 1. Yêu Cầu Tiền Quyết

Trước khi bắt đầu, đảm bảo hệ thống đã cài đặt:
- **Git**: Để clone mã nguồn.
- **Podman** (hoặc Docker): Để chạy các container.
- **Podman Compose** (hoặc Docker Compose): Để quản lý orchestration.
- **Python 3**: (Tùy chọn) Để chạy các script kiểm tra nếu cần.

## 2. Clone Mã Nguồn

Lấy mã nguồn từ repository về máy local:

```bash
git clone <repository_url>
cd OpenUDSv4.0/openuds/server
```

## 3. Cấu Hình Môi Trường

### 3.1. Thiết lập biến môi trường
Tạo file `.env` hoặc cập nhật `docker.env` nếu cần thiết để cấu hình database, secret keys, v.v.

### 3.2. Chuẩn bị SSL Certificates
OpenUDS chạy qua HTTPS, bạn cần chuẩn bị chứng chỉ SSL.
- Đặt file chứng chỉ (`.crt`) và private key (`.key`) vào thư mục `src/server/certs` hoặc cấu hình đường dẫn tương ứng trong `nginx_uds.conf`.
- **Lưu ý**: Trong môi trường dev/test, container có thể tự tạo self-signed certs nếu chưa có.

## 4. Cấu Hình Security Headers (Nginx)

Để tăng cường bảo mật, chúng ta cấu hình các headers trong file `nginx_uds.conf`.

**File:** `openuds/server/nginx_uds.conf`

Tìm block `server { listen 443 ... }` và thêm/cập nhật các directives sau:

```nginx
    # Security Headers
    add_header Cache-Control "no-store" always;
    
    # Content Security Policy (CSP) chặt chẽ:
    # - Chặn data: URI cho hình ảnh (trừ khi cần thiết, ở đây ta đã loại bỏ data: cho img-src để an toàn hơn)
    # - Chỉ cho phép script/style inline (unsafe-inline) do yêu cầu của ứng dụng hiện tại
    add_header Content-Security-Policy "default-src 'self'; upgrade-insecure-requests; block-all-mixed-content; connect-src 'self'; img-src 'self'; frame-ancestors 'self'; form-action 'self'; font-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; script-src-elem 'self' 'unsafe-inline'; object-src 'none'; base-uri 'self';" always;
    
    add_header Permissions-Policy "geolocation=(self)" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Resource-Policy "same-origin" always;
    add_header Access-Control-Allow-Credentials "true" always;
    add_header Access-Control-Allow-Origin "https://trusted-domain.com" always;
```

**Quan trọng:** Để tránh xung đột, hãy ẩn các header do Django backend gửi lên (vì Nginx đã xử lý):

```nginx
    location @proxy_to_uds {
        proxy_hide_header Content-Security-Policy;
        proxy_hide_header X-Frame-Options;
        proxy_hide_header X-XSS-Protection;
        proxy_hide_header X-Content-Type-Options;
        # ... các cấu hình khác
    }
```

## 5. Xử Lý Assets và Template

Do CSP mới chặn hình ảnh dạng Base64 (`data:image/...`), ta cần thay đổi mã nguồn HTML để sử dụng file ảnh tĩnh.

**File:** `openuds/server/src/uds/templates/uds/modern/index.html`

1.  **Loại bỏ Integrity Attributes (SRI)**:
    Nếu gặp lỗi "Failed to find a valid digest in the 'integrity' attribute", hãy xóa thuộc tính `integrity="..."` khỏi các thẻ `<script>` và `<link>`.

2.  **Thay thế Logo Base64**:
    Tìm đoạn CSS inline định nghĩa `.app-loading .logo`.
    
    **Đổi từ:**
    ```css
    background: url(data:image/png;base64,.....)
    ```
    
    **Thành:**
    ```css
    background: url(/uds/res/modern/img/udsicon.png) no-repeat center center / contain
    ```
    *Đảm bảo file `udsicon.png` tồn tại trong thư mục static.*

## 6. Build và Khởi Chạy

Sử dụng Podman Compose hoặc Docker Compose để build lại image và khởi động container.

### Bước 1: Build lại Image
Cần thiết để copy các file cấu hình và template mới vào container.

**Với Podman:**
```bash
podman compose build app
```

**Với Docker:**
```bash
docker compose build app
# Hoặc phiên bản cũ:
docker-compose build app
```

### Bước 2: Khởi động Service
Chạy container ở chế độ detached (nền).

**Với Podman:**
```bash
podman compose up -d app
```

**Với Docker:**
```bash
docker compose up -d app
# Hoặc phiên bản cũ:
docker-compose up -d app
```

*Lưu ý: Nếu gặp lỗi 502 Bad Gateway ngay sau khi start, hãy đợi khoảng 10-20 giây để Gunicorn khởi động xong. Nếu lỗi vẫn còn, thử restart lại toàn bộ stack:*

**Podman:**
```bash
podman compose down
podman compose up -d
```

**Docker:**
```bash
docker compose down
docker compose up -d
```

## 7. Kiểm Tra và Xác Minh

### 7.1. Kiểm tra Security Headers
Sử dụng `curl` để kiểm tra headers trả về từ server:

```bash
# Chạy từ máy host (nếu đã map port) hoặc bên trong container
curl -k -I https://localhost/
```

**Kết quả mong đợi:**
- `HTTP/1.1 200 OK`
- `Content-Security-Policy`: Có chứa các rule đã cấu hình.
- `Strict-Transport-Security`: `max-age=31536000...`
- Và các headers bảo mật khác.

### 7.2. Kiểm tra Giao Diện
Mở trình duyệt (nên dùng Incognito/Private mode để tránh cache):
1.  Truy cập `https://localhost/` (hoặc domain tương ứng).
2.  Mở **Developer Tools (F12)** -> Tab **Console**.
3.  Đảm bảo:
    - Không có lỗi đỏ liên quan đến **Content Security Policy**.
    - Loading spinner và Logo hiển thị bình thường.
    - Ứng dụng login và hoạt động ổn định.

## 8. Troubleshooting

- **Lỗi 502 Bad Gateway**: Kiểm tra logs của container `uds-app`.
  ```bash
  podman logs uds-app
  ```
  Nếu thấy lỗi "connection refused" tới socket, có thể Gunicorn chưa start xong hoặc bị lỗi quyền truy cập socket. Thử restart container.

- **Lỗi hiển thị (vỡ giao diện)**: Kiểm tra tab Console xem có tài nguyên nào bị chặn bởi CSP không. Nếu có, điều chỉnh lại whitelist trong `nginx_uds.conf`.

---
**Hoàn tất!** Hệ thống OpenUDS hiện đã được triển khai với cấu hình bảo mật nâng cao.
