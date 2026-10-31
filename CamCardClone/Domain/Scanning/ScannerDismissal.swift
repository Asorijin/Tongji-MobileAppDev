/// 扫描页与确认表单之间的关闭规则（纯逻辑，可在无 UIKit 的平台上回归）。
///
/// 识别成功（已产出结构化字段）时，确认表单的关闭（保存或取消）都结束扫描流程、回到名片夹；
/// 识别失败后转「手动录入」时，表单关闭同样回到名片夹（T20：取消后名片夹仍为空）。
/// 识别失败且没有打开表单时，扫描页必须保留，供用户重试或改用手动录入。
public enum ScannerDismissal {
    public static func shouldCloseScannerAfterEdit(sessionReady: Bool, isManualEntry: Bool) -> Bool {
        sessionReady || isManualEntry
    }
}
