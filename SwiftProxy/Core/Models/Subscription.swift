import Foundation

/// 订阅配置模型
/// 表示一个代理订阅源，包含订阅 URL 和解析出的节点列表
public struct Subscription: Identifiable, Codable, Hashable {
    // MARK: - Properties

    public let id: UUID
    public var name: String
    public var url: String
    public var updateInterval: TimeInterval  // 自动更新间隔（秒）
    public var lastUpdated: Date?
    public var nodes: [ProxyNode]
    public var isEnabled: Bool
    public var tags: [String]

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        name: String,
        url: String,
        updateInterval: TimeInterval = 86400,  // 默认24小时
        lastUpdated: Date? = nil,
        nodes: [ProxyNode] = [],
        isEnabled: Bool = true,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.updateInterval = updateInterval
        self.lastUpdated = lastUpdated
        self.nodes = nodes
        self.isEnabled = isEnabled
        self.tags = tags
    }

    // MARK: - Computed Properties

    /// 是否需要更新
    public var needsUpdate: Bool {
        guard let lastUpdated = lastUpdated else { return true }
        return Date().timeIntervalSince(lastUpdated) >= updateInterval
    }

    /// 活跃节点数量
    public var activeNodesCount: Int {
        nodes.filter { $0.isEnabled }.count
    }
}

/// 代理节点模型
/// 表示从订阅解析出的单个代理服务器节点
public struct ProxyNode: Identifiable, Codable, Hashable {
    // MARK: - Properties

    public let id: UUID
    public var name: String
    public var type: ProxyProtocol
    public var server: String
    public var port: Int
    public var credentials: ProxyCredentials
    public var subscriptionId: UUID?  // 所属订阅
    public var latency: TimeInterval?  // ping 测试结果（毫秒）
    public var isEnabled: Bool
    public var tags: [String]

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        name: String,
        type: ProxyProtocol,
        server: String,
        port: Int,
        credentials: ProxyCredentials,
        subscriptionId: UUID? = nil,
        latency: TimeInterval? = nil,
        isEnabled: Bool = true,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.server = server
        self.port = port
        self.credentials = credentials
        self.subscriptionId = subscriptionId
        self.latency = latency
        self.isEnabled = isEnabled
        self.tags = tags
    }

    // MARK: - Computed Properties

    /// 节点地址（用于显示）
    public var address: String {
        "\(server):\(port)"
    }

    /// 延迟状态
    public var latencyStatus: LatencyStatus {
        guard let latency = latency else { return .unknown }

        switch latency {
        case ..<100:
            return .excellent
        case 100..<300:
            return .good
        case 300..<1000:
            return .fair
        default:
            return .poor
        }
    }

    public enum LatencyStatus: String {
        case unknown = "未知"
        case excellent = "优秀"
        case good = "良好"
        case fair = "一般"
        case poor = "较差"
    }
}

/// 代理协议类型
public enum ProxyProtocol: String, Codable, CaseIterable {
    case http
    case https
    case socks5
    case shadowsocks = "ss"
    case shadowsocksR = "ssr"
    case vmess
    case vless
    case trojan

    public var displayName: String {
        switch self {
        case .http: return "HTTP"
        case .https: return "HTTPS"
        case .socks5: return "SOCKS5"
        case .shadowsocks: return "Shadowsocks"
        case .shadowsocksR: return "ShadowsocksR"
        case .vmess: return "VMess"
        case .vless: return "VLESS"
        case .trojan: return "Trojan"
        }
    }

    public var systemImageName: String {
        switch self {
        case .http, .https:
            return "globe"
        case .socks5:
            return "network"
        case .shadowsocks, .shadowsocksR:
            return "eye.slash"
        case .vmess, .vless:
            return "arrow.triangle.branch"
        case .trojan:
            return "shield.lefthalf.filled"
        }
    }
}

/// 代理认证信息
/// 针对不同协议的认证凭据
public struct ProxyCredentials: Codable, Hashable {
    // MARK: - Common
    public var username: String?
    public var password: String?

    // MARK: - Shadowsocks
    public var method: String?  // 加密方法: aes-256-gcm, chacha20-poly1305, etc

    // MARK: - V2Ray (VMess/VLESS)
    public var uuid: String?
    public var alterId: Int?
    public var security: String?  // auto, aes-128-gcm, chacha20-poly1305, none

    // MARK: - Transport
    public var network: String?  // tcp, ws, http, kcp, quic
    public var tls: Bool?
    public var skipCertVerify: Bool?
    public var sni: String?  // Server Name Indication

    // MARK: - WebSocket
    public var wsPath: String?
    public var wsHeaders: [String: String]?

    // MARK: - HTTP/2
    public var httpPath: String?
    public var httpHost: [String]?

    // MARK: - Initialization

    public init(
        username: String? = nil,
        password: String? = nil,
        method: String? = nil,
        uuid: String? = nil,
        alterId: Int? = nil,
        security: String? = nil,
        network: String? = nil,
        tls: Bool? = nil,
        skipCertVerify: Bool? = nil,
        sni: String? = nil,
        wsPath: String? = nil,
        wsHeaders: [String: String]? = nil,
        httpPath: String? = nil,
        httpHost: [String]? = nil
    ) {
        self.username = username
        self.password = password
        self.method = method
        self.uuid = uuid
        self.alterId = alterId
        self.security = security
        self.network = network
        self.tls = tls
        self.skipCertVerify = skipCertVerify
        self.sni = sni
        self.wsPath = wsPath
        self.wsHeaders = wsHeaders
        self.httpPath = httpPath
        self.httpHost = httpHost
    }

    // MARK: - Factory Methods

    /// 创建 Shadowsocks 凭据
    public static func shadowsocks(password: String, method: String) -> ProxyCredentials {
        ProxyCredentials(password: password, method: method)
    }

    /// 创建 VMess 凭据
    public static func vmess(
        uuid: String,
        alterId: Int = 0,
        security: String = "auto",
        network: String = "tcp",
        tls: Bool = false
    ) -> ProxyCredentials {
        ProxyCredentials(
            uuid: uuid,
            alterId: alterId,
            security: security,
            network: network,
            tls: tls
        )
    }

    /// 创建 Trojan 凭据
    public static func trojan(
        password: String,
        sni: String? = nil,
        skipCertVerify: Bool = false
    ) -> ProxyCredentials {
        ProxyCredentials(
            password: password,
            tls: true,
            skipCertVerify: skipCertVerify,
            sni: sni
        )
    }
}

// MARK: - 订阅格式枚举

/// 订阅格式类型
public enum SubscriptionFormat: String, CaseIterable {
    case clash       // Clash YAML 格式
    case v2ray       // V2Ray JSON 格式
    case ssSIP008    // Shadowsocks SIP008 JSON
    case base64      // Base64 编码的 URI 列表
    case unknown

    public var displayName: String {
        switch self {
        case .clash: return "Clash"
        case .v2ray: return "V2Ray"
        case .ssSIP008: return "Shadowsocks"
        case .base64: return "Base64"
        case .unknown: return "未知"
        }
    }
}
