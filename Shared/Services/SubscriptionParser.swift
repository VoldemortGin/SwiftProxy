import Foundation
import Yams

/// 订阅解析器协议
/// 定义了所有订阅解析器必须实现的接口
public protocol SubscriptionParser {
    /// 解析订阅数据
    /// - Parameter data: 原始订阅数据
    /// - Returns: 解析出的代理节点列表
    /// - Throws: 解析失败时抛出错误
    func parse(data: Data) throws -> [ProxyNode]

    /// 检测数据是否符合此解析器的格式
    /// - Parameter data: 待检测的数据
    /// - Returns: 是否符合格式
    func canParse(data: Data) -> Bool
}

/// 订阅解析器工厂
/// 自动检测订阅格式并选择合适的解析器
public class SubscriptionParserFactory {

    /// 所有可用的解析器（按优先级排序）
    private static let parsers: [SubscriptionParser] = [
        ClashParser(),
        V2RayParser(),
        SIP008Parser(),
        Base64Parser()
    ]

    /// 自动检测并解析订阅数据
    /// - Parameter data: 订阅数据
    /// - Returns: 解析出的节点列表
    /// - Throws: 如果没有合适的解析器或解析失败
    public static func parse(data: Data) throws -> [ProxyNode] {
        // 尝试所有解析器
        for parser in parsers {
            if parser.canParse(data: data) {
                return try parser.parse(data: data)
            }
        }

        throw SubscriptionError.unsupportedFormat
    }

    /// 检测订阅格式
    /// - Parameter data: 订阅数据
    /// - Returns: 检测到的格式类型
    public static func detectFormat(data: Data) -> SubscriptionFormat {
        if ClashParser().canParse(data: data) {
            return .clash
        } else if V2RayParser().canParse(data: data) {
            return .v2ray
        } else if SIP008Parser().canParse(data: data) {
            return .ssSIP008
        } else if Base64Parser().canParse(data: data) {
            return .base64
        } else {
            return .unknown
        }
    }
}

// MARK: - Clash Parser

/// Clash 订阅解析器
/// 解析 Clash YAML 格式的订阅
public class ClashParser: SubscriptionParser {

    public func canParse(data: Data) -> Bool {
        guard let str = String(data: data, encoding: .utf8) else { return false }

        // 检查是否包含 Clash 特征关键字
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("proxies:") || trimmed.contains("proxy-groups:")
    }

    public func parse(data: Data) throws -> [ProxyNode] {
        guard let str = String(data: data, encoding: .utf8) else {
            throw SubscriptionError.invalidEncoding
        }

        // 解析 YAML
        guard let yaml = try? Yams.load(yaml: str) as? [String: Any] else {
            throw SubscriptionError.invalidYAML
        }

        // 提取 proxies 数组
        guard let proxies = yaml["proxies"] as? [[String: Any]] else {
            throw SubscriptionError.missingProxies
        }

        // 解析每个代理节点
        var nodes: [ProxyNode] = []

        for proxy in proxies {
            if let node = try? parseClashProxy(proxy) {
                nodes.append(node)
            }
        }

        return nodes
    }

    private func parseClashProxy(_ dict: [String: Any]) throws -> ProxyNode {
        guard let name = dict["name"] as? String,
              let typeStr = dict["type"] as? String,
              let server = dict["server"] as? String,
              let port = dict["port"] as? Int else {
            throw SubscriptionError.missingRequiredFields
        }

        // 解析协议类型
        let type: ProxyProtocol
        switch typeStr.lowercased() {
        case "ss", "shadowsocks":
            type = .shadowsocks
        case "vmess":
            type = .vmess
        case "trojan":
            type = .trojan
        case "socks5":
            type = .socks5
        case "http", "https":
            type = .http
        default:
            throw SubscriptionError.unsupportedProtocol(typeStr)
        }

        // 解析凭据
        let credentials = try parseClashCredentials(type: type, dict: dict)

        return ProxyNode(
            name: name,
            type: type,
            server: server,
            port: port,
            credentials: credentials
        )
    }

    private func parseClashCredentials(type: ProxyProtocol, dict: [String: Any]) throws -> ProxyCredentials {
        switch type {
        case .shadowsocks:
            guard let password = dict["password"] as? String,
                  let cipher = dict["cipher"] as? String else {
                throw SubscriptionError.missingRequiredFields
            }
            return .shadowsocks(password: password, method: cipher)

        case .vmess:
            guard let uuid = dict["uuid"] as? String else {
                throw SubscriptionError.missingRequiredFields
            }
            let alterId = dict["alterId"] as? Int ?? 0
            let cipher = dict["cipher"] as? String ?? "auto"
            let network = dict["network"] as? String ?? "tcp"
            let tls = dict["tls"] as? Bool ?? false

            var creds = ProxyCredentials.vmess(
                uuid: uuid,
                alterId: alterId,
                security: cipher,
                network: network,
                tls: tls
            )

            // WebSocket 设置
            if network == "ws", let wsOpts = dict["ws-opts"] as? [String: Any] {
                creds.wsPath = wsOpts["path"] as? String
                creds.wsHeaders = wsOpts["headers"] as? [String: String]
            }

            // TLS 设置
            if tls {
                creds.sni = dict["sni"] as? String ?? dict["servername"] as? String
                creds.skipCertVerify = dict["skip-cert-verify"] as? Bool ?? false
            }

            return creds

        case .trojan:
            guard let password = dict["password"] as? String else {
                throw SubscriptionError.missingRequiredFields
            }
            let sni = dict["sni"] as? String
            let skipVerify = dict["skip-cert-verify"] as? Bool ?? false

            return .trojan(password: password, sni: sni, skipCertVerify: skipVerify)

        default:
            return ProxyCredentials()
        }
    }
}

// MARK: - Base64 Parser

/// Base64 订阅解析器
/// 解析 Base64 编码的 URI 列表格式订阅
public class Base64Parser: SubscriptionParser {

    public func canParse(data: Data) -> Bool {
        // 尝试 Base64 解码
        guard let decoded = Data(base64Encoded: data) else { return false }
        guard let str = String(data: decoded, encoding: .utf8) else { return false }

        // 检查是否包含代理协议 URI
        let uriPrefixes = ["ss://", "ssr://", "vmess://", "trojan://", "socks://"]
        return uriPrefixes.contains { str.contains($0) }
    }

    public func parse(data: Data) throws -> [ProxyNode] {
        // Base64 解码
        guard let decoded = Data(base64Encoded: data) else {
            throw SubscriptionError.invalidBase64
        }

        guard let str = String(data: decoded, encoding: .utf8) else {
            throw SubscriptionError.invalidEncoding
        }

        // 按行分割
        let lines = str.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var nodes: [ProxyNode] = []

        for line in lines {
            if let node = try? parseURI(line) {
                nodes.append(node)
            }
        }

        return nodes
    }

    private func parseURI(_ uri: String) throws -> ProxyNode {
        if uri.hasPrefix("ss://") {
            return try parseShadowsocksURI(uri)
        } else if uri.hasPrefix("vmess://") {
            return try parseVMessURI(uri)
        } else if uri.hasPrefix("trojan://") {
            return try parseTrojanURI(uri)
        } else {
            throw SubscriptionError.unsupportedProtocol(uri)
        }
    }

    private func parseShadowsocksURI(_ uri: String) throws -> ProxyNode {
        // ss://base64(method:password)@server:port#name
        let cleaned = String(uri.dropFirst(5))  // 去掉 "ss://"

        // 提取名称（# 后面的部分）
        let parts = cleaned.components(separatedBy: "#")
        let name = parts.count > 1 ? parts[1].removingPercentEncoding ?? "Shadowsocks" : "Shadowsocks"
        let mainPart = parts[0]

        // 分离服务器和认证信息
        let components = mainPart.components(separatedBy: "@")
        guard components.count == 2 else {
            throw SubscriptionError.invalidURI
        }

        // 解析认证信息（Base64 编码的 method:password）
        guard let authData = Data(base64Encoded: components[0]),
              let authStr = String(data: authData, encoding: .utf8) else {
            throw SubscriptionError.invalidBase64
        }

        let authParts = authStr.components(separatedBy: ":")
        guard authParts.count == 2 else {
            throw SubscriptionError.invalidURI
        }

        let method = authParts[0]
        let password = authParts[1]

        // 解析服务器地址和端口
        let serverParts = components[1].components(separatedBy: ":")
        guard serverParts.count == 2,
              let port = Int(serverParts[1]) else {
            throw SubscriptionError.invalidURI
        }

        let server = serverParts[0]

        return ProxyNode(
            name: name,
            type: .shadowsocks,
            server: server,
            port: port,
            credentials: .shadowsocks(password: password, method: method)
        )
    }

    private func parseVMessURI(_ uri: String) throws -> ProxyNode {
        // vmess://base64(json)
        let cleaned = String(uri.dropFirst(8))  // 去掉 "vmess://"

        guard let jsonData = Data(base64Encoded: cleaned),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw SubscriptionError.invalidBase64
        }

        guard let server = json["add"] as? String,
              let port = json["port"] as? Int,
              let uuid = json["id"] as? String else {
            throw SubscriptionError.missingRequiredFields
        }

        let name = json["ps"] as? String ?? "VMess"
        let alterId = json["aid"] as? Int ?? 0
        let network = json["net"] as? String ?? "tcp"
        let tls = (json["tls"] as? String) == "tls"

        var credentials = ProxyCredentials.vmess(
            uuid: uuid,
            alterId: alterId,
            security: "auto",
            network: network,
            tls: tls
        )

        // WebSocket 设置
        if network == "ws" {
            credentials.wsPath = json["path"] as? String
            if let host = json["host"] as? String {
                credentials.wsHeaders = ["Host": host]
            }
        }

        // TLS 设置
        if tls {
            credentials.sni = json["sni"] as? String ?? json["host"] as? String
        }

        return ProxyNode(
            name: name,
            type: .vmess,
            server: server,
            port: port,
            credentials: credentials
        )
    }

    private func parseTrojanURI(_ uri: String) throws -> ProxyNode {
        // trojan://password@server:port#name
        let cleaned = String(uri.dropFirst(9))  // 去掉 "trojan://"

        // 提取名称
        let parts = cleaned.components(separatedBy: "#")
        let name = parts.count > 1 ? parts[1].removingPercentEncoding ?? "Trojan" : "Trojan"
        let mainPart = parts[0]

        // 分离密码和服务器
        let components = mainPart.components(separatedBy: "@")
        guard components.count == 2 else {
            throw SubscriptionError.invalidURI
        }

        let password = components[0]

        // 解析服务器和端口
        let serverParts = components[1].components(separatedBy: ":")
        guard serverParts.count == 2,
              let port = Int(serverParts[1]) else {
            throw SubscriptionError.invalidURI
        }

        return ProxyNode(
            name: name,
            type: .trojan,
            server: serverParts[0],
            port: port,
            credentials: .trojan(password: password, sni: nil, skipCertVerify: false)
        )
    }
}

// MARK: - V2Ray Parser

/// V2Ray 订阅解析器
/// 解析 V2Ray JSON 格式的订阅
public class V2RayParser: SubscriptionParser {

    public func canParse(data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        // 检查 V2Ray 特征字段
        return json["outbounds"] != nil || json["servers"] != nil
    }

    public func parse(data: Data) throws -> [ProxyNode] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SubscriptionError.invalidJSON
        }

        // V2Ray 配置文件可能包含 outbounds 或 servers
        if let outbounds = json["outbounds"] as? [[String: Any]] {
            return try parseOutbounds(outbounds)
        } else if let servers = json["servers"] as? [[String: Any]] {
            return try parseServers(servers)
        } else {
            throw SubscriptionError.missingProxies
        }
    }

    private func parseOutbounds(_ outbounds: [[String: Any]]) throws -> [ProxyNode] {
        var nodes: [ProxyNode] = []

        for outbound in outbounds {
            if let node = try? parseOutbound(outbound) {
                nodes.append(node)
            }
        }

        return nodes
    }

    private func parseOutbound(_ dict: [String: Any]) throws -> ProxyNode {
        guard let settings = dict["settings"] as? [String: Any],
              let vnext = settings["vnext"] as? [[String: Any]],
              let first = vnext.first else {
            throw SubscriptionError.missingRequiredFields
        }

        guard let server = first["address"] as? String,
              let port = first["port"] as? Int,
              let users = first["users"] as? [[String: Any]],
              let user = users.first,
              let uuid = user["id"] as? String else {
            throw SubscriptionError.missingRequiredFields
        }

        let name = (dict["tag"] as? String) ?? "V2Ray"
        let alterId = user["alterId"] as? Int ?? 0
        let security = user["security"] as? String ?? "auto"

        // Stream settings
        var network = "tcp"
        var tls = false
        var wsPath: String?
        var sni: String?

        if let streamSettings = dict["streamSettings"] as? [String: Any] {
            network = streamSettings["network"] as? String ?? "tcp"
            tls = (streamSettings["security"] as? String) == "tls"

            if network == "ws", let wsSettings = streamSettings["wsSettings"] as? [String: Any] {
                wsPath = wsSettings["path"] as? String
            }

            if tls, let tlsSettings = streamSettings["tlsSettings"] as? [String: Any] {
                sni = tlsSettings["serverName"] as? String
            }
        }

        var credentials = ProxyCredentials.vmess(
            uuid: uuid,
            alterId: alterId,
            security: security,
            network: network,
            tls: tls
        )

        credentials.wsPath = wsPath
        credentials.sni = sni

        return ProxyNode(
            name: name,
            type: .vmess,
            server: server,
            port: port,
            credentials: credentials
        )
    }

    private func parseServers(_ servers: [[String: Any]]) throws -> [ProxyNode] {
        // 简化处理，类似 outbounds
        return []
    }
}

// MARK: - SIP008 Parser

/// Shadowsocks SIP008 订阅解析器
/// 解析 Shadowsocks SIP008 JSON 格式的订阅
public class SIP008Parser: SubscriptionParser {

    public func canParse(data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        // 检查 SIP008 特征字段
        return json["version"] != nil && json["servers"] != nil
    }

    public func parse(data: Data) throws -> [ProxyNode] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SubscriptionError.invalidJSON
        }

        guard let servers = json["servers"] as? [[String: Any]] else {
            throw SubscriptionError.missingProxies
        }

        var nodes: [ProxyNode] = []

        for server in servers {
            if let node = try? parseSIP008Server(server) {
                nodes.append(node)
            }
        }

        return nodes
    }

    private func parseSIP008Server(_ dict: [String: Any]) throws -> ProxyNode {
        guard let server = dict["server"] as? String,
              let port = dict["server_port"] as? Int,
              let password = dict["password"] as? String,
              let method = dict["method"] as? String else {
            throw SubscriptionError.missingRequiredFields
        }

        let name = dict["remarks"] as? String ?? "\(server):\(port)"

        return ProxyNode(
            name: name,
            type: .shadowsocks,
            server: server,
            port: port,
            credentials: .shadowsocks(password: password, method: method)
        )
    }
}

// MARK: - Errors

/// 订阅解析错误
public enum SubscriptionError: Error, LocalizedError {
    case unsupportedFormat
    case invalidEncoding
    case invalidBase64
    case invalidYAML
    case invalidJSON
    case invalidURI
    case missingProxies
    case missingRequiredFields
    case unsupportedProtocol(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "不支持的订阅格式"
        case .invalidEncoding:
            return "无效的文本编码"
        case .invalidBase64:
            return "无效的 Base64 编码"
        case .invalidYAML:
            return "无效的 YAML 格式"
        case .invalidJSON:
            return "无效的 JSON 格式"
        case .invalidURI:
            return "无效的 URI 格式"
        case .missingProxies:
            return "订阅中未找到代理节点"
        case .missingRequiredFields:
            return "缺少必需的字段"
        case .unsupportedProtocol(let proto):
            return "不支持的协议类型: \(proto)"
        }
    }
}
