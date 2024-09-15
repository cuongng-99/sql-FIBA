---------------------------------------------------------------------------------
------------------------ 3. Tính số tiền lãi ------------------------------------
---------------------------------------------------------------------------------
/* -- Check nội tệ hay ngoại tệ
- Ngoại tệ => lãi auto = 0
- Nội tệ:
	- Ngày rút nhỏ hơn ngày đến hạn => lãi 0.1%
	- Ngày rút lớn hơn ngày đến hạn
		- Nếu chọn tự động gia hạn: 
			Tiền lãi = Theo công thức lãi kép theo năm
		- Nếu ko tự động gia hạn: 
			Tiền lãi = Lãi suất tính đến khi hện hạn, sau ngày hết hạn tính lãi 0.1%
*/

----------------------------------------------------------------------------------
---- 3.1 Tính lãi các khoản rút trước hạn: Lãi suất = 0.1%
-- DROP FUNCTION  dbo.TINH_LAI_RUT_TRUOC_HAN;

CREATE FUNCTION dbo.TINH_LAI_RUT_TRUOC_HAN (
	@NGAY_GUI DATE,
	@NGAY_RUT DATE,
	@SO_TIEN DECIMAL(18,2)
)
RETURNS DECIMAL(18,2)
AS 
BEGIN 
	DECLARE @DAYS INT
	DECLARE @SO_TIEN_LAI DECIMAL(18,2)

	-- Tính số ngày đã gửi
	SET @DAYS = DATEDIFF(DAY, @NGAY_GUI, @NGAY_RUT)
	-- Tính số tiền lãi
	SET @SO_TIEN_LAI = @SO_TIEN * 0.1 / 100 * @DAYS / 365.0

	RETURN @SO_TIEN_LAI
END;

----------------------------------------------------------------------------------
---- 3.2 Tính lãi cho các khoản rút sau ngày đến hạn và KHÔNG chọn tự động gia hạn
-- DROP FUNCTION dbo.TINH_LAI_RUT_SAU_HAN_VA_KHONG_GIA_HAN

CREATE FUNCTION dbo.TINH_LAI_RUT_SAU_HAN_VA_KHONG_GIA_HAN(
	@NGAY_GUI DATE,
	@NGAY_DEN_HAN DATE,
	@NGAY_RUT DATE,
	@SO_TIEN DECIMAL(18,2),
	@LAI_SUAT DECIMAL(5,2),
	@KY_HAN_THANG INT
)
RETURNS DECIMAL(18,2)
AS 
BEGIN 
	DECLARE @SO_NGAY_SAU_HAN INT
	DECLARE @SO_TIEN_LAI DECIMAL(18,2)

	-- Tính số tiền lãi khi đến hạn
	SET @SO_TIEN_LAI = @SO_TIEN * @LAI_SUAT / 100 / 12.0 * @KY_HAN_THANG 
	-- Tính số lãi sau ngày đến hạn
	SET @SO_NGAY_SAU_HAN = DATEDIFF(DAY, @NGAY_DEN_HAN, @NGAY_RUT)
	-- Cộng số tiền lãi cuối cùng
	SET @SO_TIEN_LAI += @SO_TIEN_LAI * 0.1 / 100 / 365.0 * @SO_NGAY_SAU_HAN
	
	RETURN @SO_TIEN_LAI
END;
-- SELECT dbo.TINH_LAI_RUT_SAU_HAN_VA_KHONG_GIA_HAN('2023-02-12', '2024-02-12', '2024-02-12', 180000000.00, 9.60, 12)


----------------------------------------------------------------------------------
---- 3.3 Tính lãi cho các khoản rút sau ngày đến hạn và chọn tự động gia hạn
/* Ý tưởng: 
	- Tính ra được số kỳ nguyên mà đã tự động gia hạn thêm: 
		- Lấy datediff theo tháng của ngày rút và ngày đến hạn 
		- Chia lấy phần nguyên tính ra được số kỳ nguyên
		=> số này sẽ tính theo công thức lãi kép: Giả sử lãi kép tính theo năm, các trường hợp gửi kỳ hạn < 1 năm chưa xét riêng
	- Còn số ngày lẻ dư ra chưa đủ kỳ:
		- Ngày rút - (Ngày đến hạn + interval month (Số kỳ nguyên đã tính)
		=> số này tính theo công thức lãi 0.1%
*/
-- DROP FUNCTION dbo.TINH_LAI_RUT_SAU_HAN_VA_TU_GIA_HAN

CREATE FUNCTION dbo.TINH_LAI_RUT_SAU_HAN_VA_TU_GIA_HAN(
	@NGAY_GUI DATE,
	@NGAY_DEN_HAN DATE,
	@NGAY_RUT DATE,
	@SO_TIEN DECIMAL(18,2),
	@LAI_SUAT DECIMAL(5,2),
	@KY_HAN_THANG INT
)
RETURNS DECIMAL(18,2)
AS 
BEGIN 
	DECLARE @SO_KY_NGUYEN INT
	DECLARE @SO_NGAY_LE_CON_LAI INT
	DECLARE @SO_TIEN_LAI DECIMAL(18,2)

	-- Tính số kỳ nguyên: 
	SET @SO_KY_NGUYEN = ROUND(DATEDIFF(YEAR, @NGAY_DEN_HAN, @NGAY_RUT) / (@KY_HAN_THANG / 12), 0) 

	-- Tính số ngày lẻ dư chưa đủ 1 kỳ nguyên
	SET @SO_NGAY_LE_CON_LAI = DATEDIFF(DAY, DATEADD(YEAR, @SO_KY_NGUYEN, @NGAY_DEN_HAN), @NGAY_RUT)

	-- Tính số tiền lãi khi đến kỳ rút
	SET @SO_TIEN_LAI = @SO_TIEN * POWER((1 + @LAI_SUAT / 100.0), @SO_KY_NGUYEN + 1) - @SO_TIEN -- @SO_KY_NGUYEN + 1 vì tính cả năm đầu tiên
	SET @SO_TIEN_LAI *= CEILING(@KY_HAN_THANG / 12)

	-- Tính Số tiền lãi cọng thêm phần ngày dư ra chưa đủ kỳ nếu có
	SET @SO_TIEN_LAI +=  @SO_TIEN * POWER((1 + @LAI_SUAT / 100.0), @SO_KY_NGUYEN) * 0.1 / 100 / 365.0 * @SO_NGAY_LE_CON_LAI
	
	RETURN @SO_TIEN_LAI
END;
-- SELECT dbo.TINH_LAI_RUT_SAU_HAN_VA_TU_GIA_HAN('2023-01-01', '2024-01-01', '2026-01-15', 100000000.00, 10.0, 12)




-- 3.N Tạo procedure update tiền lãi
-- DROP PROC TINH_TIEN_LAI

CREATE PROC TINH_TIEN_LAI AS
BEGIN
	-- Trường hợp tiền gửi là ngoại tệ
	UPDATE TIENGUI_TIETKIEM
	SET SOTIEN_LAI = 0
	WHERE LOAITIEN != 'VND'

	-- Trường hợp ngày rút nhỏ hơn ngày đến hạn
	UPDATE TIENGUI_TIETKIEM
	SET SOTIEN_LAI = dbo.TINH_LAI_RUT_TRUOC_HAN(NGAY_GUI, NGAY_RUT, SOTIEN)
	WHERE NGAY_RUT < NGAY_DENHAN

	-- Trường hợp ngày rút từ sau ngày đến hạn nhưng ko tự động gia hạn
	UPDATE TIENGUI_TIETKIEM
	SET SOTIEN_LAI = dbo.TINH_LAI_RUT_SAU_HAN_VA_KHONG_GIA_HAN(NGAY_GUI, NGAY_DENHAN, NGAY_RUT, SOTIEN, LAISUAT, KY_HAN)
	WHERE	NGAY_RUT >= NGAY_DENHAN
			AND TUGIAHAN = 0
	
	-- Trường hợp ngày rút từ sau ngày đến hạn và tự động gia hạn
	UPDATE TIENGUI_TIETKIEM
	SET SOTIEN_LAI = dbo.TINH_LAI_RUT_SAU_HAN_VA_TU_GIA_HAN(NGAY_GUI, NGAY_DENHAN, NGAY_RUT, SOTIEN, LAISUAT, KY_HAN)
	WHERE	NGAY_RUT >= NGAY_DENHAN
			AND TUGIAHAN = 1
END;


EXEC TINH_TIEN_LAI;
