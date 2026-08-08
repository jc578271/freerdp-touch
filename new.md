**Có, tự code được.** Với trường hợp của bạn, tôi không khuyên viết một app RDP mới từ đầu mà nên **sửa trực tiếp phần input của `xfreerdp3`** hoặc thêm một lớp gesture vào X11 client.

FreeRDP đã có kênh **RDPEI** để gửi touch contact thật sang Windows, nhưng cách client X11 thu nhận và biến sự kiện cảm ứng thành RDPEI còn chưa tốt. Các lỗi về multitouch không được gửi, giữ lâu mới thành chuột phải và trải nghiệm touchscreen không tự nhiên đã được báo cáo trong dự án. Bản FreeRDP mới cũng vẫn đang sửa lỗi “không gửi đủ touch events”, cho thấy phần này vẫn đang được phát triển. ([GitHub][1])

## Tôi sẽ làm theo hướng này

```text
Màn hình cảm ứng OneMix 3
          ↓
XInput2 touch events
          ↓
Gesture recognizer tùy chỉnh
          ↓
 ┌─────────────────────────┐
 │ Direct touch qua RDPEI  │
 │ hoặc mouse/keyboard     │
 └─────────────────────────┘
          ↓
Windows qua RDP
```

Các thao tác có thể triển khai:

* Chạm ngắn: click hoặc touch native.
* Một ngón kéo: gửi touch thật để cuộn ứng dụng Windows.
* Hai ngón kéo: cuộn như touchpad khi ứng dụng không hỗ trợ touch.
* Pinch hai ngón: gửi multitouch thật hoặc `Ctrl + wheel`.
* Nhấn giữ khoảng 500–700 ms: chuột phải.
* Ba ngón vuốt: gửi `Alt+Tab` vào Windows.
* Nút Windows và `Alt+Tab`: giữ trong phiên remote thay vì để Linux xử lý.
* Tự chuyển giữa **Direct Touch** và **Mouse Pointer**, giống Windows App Android.

## Hai cách triển khai

### 1. Patch trực tiếp `xfreerdp3`

Đây là phương án tốt nhất về lâu dài:

* Độ trễ thấp nhất.
* Không phải giả lập chuột qua `uinput`.
* Có thể gửi RDPEI touch contact trực tiếp.
* Fullscreen và keyboard grab hoạt động đồng bộ.

Nhược điểm là phải tự build FreeRDP và duy trì patch khi nâng phiên bản.

### 2. Viết daemon gesture riêng

Daemon đọc `/dev/input/event*`, nhận dạng gesture rồi phát chuột/phím ảo cho `xfreerdp3`.

Ưu điểm:

* Dễ viết và thử nghiệm.
* Không sửa mã nguồn FreeRDP.
* Có thể dùng ngay với bản Debian hiện tại.

Nhược điểm:

* Khó gửi touch native hoàn chỉnh qua RDPEI.
* Chủ yếu biến gesture thành mouse/keyboard.
* Có thể bị trễ hoặc xung đột với X11/libinput.

Vì mục tiêu của bạn là **native và cảm ứng tốt**, tôi chọn **patch trực tiếp X11 client của FreeRDP**.

## Có thể đạt ngang Windows App Android không?

Có thể cải thiện rất nhiều, nhất là:

* cuộn một ngón;
* nhấn giữ;
* pinch;
* chuyển direct-touch/mouse;
* gesture ba ngón;
* bắt phím fullscreen.

Nhưng khó đảm bảo giống 100% Windows App vì Microsoft có thuật toán gesture riêng không công khai. Tuy nhiên, ta có thể thiết kế hành vi phù hợp chính xác với màn hình OneMix 3, thậm chí dễ dùng hơn FreeRDP mặc định.

Để bắt đầu patch đúng máy, tôi cần đầu ra của các lệnh sau:

```bash
xfreerdp3 /version
echo "$XDG_SESSION_TYPE"
xinput list
sudo libinput list-devices
```

Và lệnh `xfreerdp3` hiện tại bạn đang dùng. Từ đó có thể viết bản patch đầu tiên cho **một ngón cuộn + nhấn giữ chuột phải + hai ngón pinch**, rồi build thành gói `.deb` để cài như ứng dụng bình thường.

[1]: https://github.com/FreeRDP/FreeRDP/issues/8253?utm_source=chatgpt.com "Support normal touch-screen interaction · Issue #8253"
