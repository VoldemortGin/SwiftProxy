#!/usr/bin/env swift

import Foundation

// 测试 boslife 订阅导入
// 使用方法：swift test_boslife_subscription.swift <你的订阅链接>

@main
struct SubscriptionTester {
    static func main() async throws {
        guard CommandLine.arguments.count > 1 else {
            print("使用方法: swift test_boslife_subscription.swift <订阅URL>")
            print("示例: swift test_boslife_subscription.swift https://example.com/clash/subscribe")
            return
        }

        let subscriptionURL = CommandLine.arguments[1]

        print("🔄 开始测试 boslife 订阅...")
        print("📋 订阅链接: \(subscriptionURL)")

        // 下载订阅数据
        guard let url = URL(string: subscriptionURL) else {
            print("❌ 无效的 URL")
            return
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("❌ 下载失败")
            return
        }

        print("✅ 下载成功，数据大小: \(data.count) 字节")

        // 检测格式
        if let yamlString = String(data: data, encoding: .utf8),
           yamlString.contains("proxies:") || yamlString.contains("proxy-groups:") {
            print("📦 检测到格式: Clash YAML")
            print("\n预览前 500 字符:")
            print(String(yamlString.prefix(500)))
        } else if let jsonString = String(data: data, encoding: .utf8),
                  jsonString.contains("outbounds") || jsonString.contains("servers") {
            print("📦 检测到格式: V2Ray JSON")
        } else if let base64String = String(data: data, encoding: .utf8),
                  base64String.hasPrefix("ss://") || base64String.hasPrefix("vmess://") {
            print("📦 检测到格式: Base64 URI 列表")
        } else {
            print("⚠️ 未识别的格式，尝试 Base64 解码...")
            if let decodedData = Data(base64Encoded: data),
               let decodedString = String(data: decodedData, encoding: .utf8) {
                print("✅ Base64 解码成功")
                print("\n预览前 500 字符:")
                print(String(decodedString.prefix(500)))
            }
        }

        print("\n💡 下一步:")
        print("1. 在 SwiftProxy 应用中打开 '订阅管理'")
        print("2. 点击 '添加订阅'")
        print("3. 粘贴此 URL 并保存")
        print("4. 系统会自动解析并导入所有节点")
    }
}
