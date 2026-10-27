public import Foundation

#if os(iOS)
    import HealthKit
#endif

/// 健康 App 里读到的一段时间（docs/模块/产品优化.md R5）：原样交给服务器，归到哪天、和你说的是不是同一次由服务器定
public struct HealthSnapshot: Sendable, Hashable {
    /// 每小时的步数（iPhone 和手表的，健康 App 已经合在一起、不重复）
    public struct Step: Sendable, Hashable {
        public let start: Date
        public let count: Int

        public init(start: Date, count: Int) {
            self.start = start
            self.count = count
        }
    }

    /// 睡眠的一段：asleep 睡着（深睡、核心、快速眼动都算）、inBed 在床上、awake 中间醒着
    public struct Sleep: Sendable, Hashable {
        public let start: Date
        public let end: Date
        public let stage: String

        public init(start: Date, end: Date, stage: String) {
            self.start = start
            self.end = end
            self.stage = stage
        }
    }

    /// 一次锻炼：activity 是 running、cycling…（服务器认得的几种，别的是 other）
    public struct Workout: Sendable, Hashable {
        public let id: String
        public let activity: String
        public let start: Date
        public let end: Date
        public let minutes: Double
        /// 距离（公里）
        public let kilometers: Double?

        public init(id: String, activity: String, start: Date, end: Date, minutes: Double, kilometers: Double?) {
            self.id = id
            self.activity = activity
            self.start = start
            self.end = end
            self.minutes = minutes
            self.kilometers = kilometers
        }
    }

    public let from: Date
    public let to: Date
    public var steps: [Step]
    public var sleep: [Sleep]
    public var workouts: [Workout]

    public init(from: Date, to: Date, steps: [Step], sleep: [Sleep], workouts: [Workout]) {
        self.from = from
        self.to = to
        self.steps = steps
        self.sleep = sleep
        self.workouts = workouts
    }
}

/// 从哪读健康的数据：平时是健康 App；界面测试用假的（App 里的 FakeHealth）
public protocol HealthSource: Sendable {
    /// 这台设备上有没有健康 App
    var isAvailable: Bool { get }
    /// 问系统能不能读这三样：第一次弹系统的权限页，以后再问不弹。系统不告诉 App 你给没给读，只知道问完了没有
    func requestAccess() async -> Bool
    /// 读 [from, to) 这段时间的
    func read(from: Date, to: Date) async throws -> HealthSnapshot
}

#if os(iOS)
    /// 健康 App：只读步数、睡眠、锻炼（锻炼的距离要读三种距离），不往里写
    public final class HealthKitSource: HealthSource {
        private let store = HKHealthStore()

        public init() {}

        public var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

        static let readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount), HKCategoryType(.sleepAnalysis), HKObjectType.workoutType(),
            HKQuantityType(.distanceWalkingRunning), HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
        ]

        public func requestAccess() async -> Bool {
            guard isAvailable else { return false }
            do {
                try await store.requestAuthorization(toShare: [], read: Self.readTypes)
                return true
            } catch {
                return false
            }
        }

        public func read(from: Date, to: Date) async throws -> HealthSnapshot {
            let earliest = await earliestReadable()
            let start = min(max(from, earliest), to)
            async let steps = readSteps(from: start, to: to)
            async let sleep = readSleep(from: start, to: to)
            async let workouts = readWorkouts(from: start, to: to)
            return try await HealthSnapshot(from: start, to: to, steps: steps, sleep: sleep, workouts: workouts)
        }

        /// 你在系统那一页只给看某天以后的（iOS 27 的有限访问）：更早的读不到。送给服务器的起点写这一天，
        /// 服务器才知道最早那天没读全（不然那天只有半天的步数、半截的一觉）
        private func earliestReadable() async -> Date {
            let types: Set<HKObjectType> = [
                HKQuantityType(.stepCount), HKCategoryType(.sleepAnalysis), HKObjectType.workoutType(),
            ]
            let dates = (try? await store.earliestAuthorizedSampleDate(for: types)) ?? [:]
            return dates.values.max() ?? .distantPast
        }

        /// 每小时一格的步数（健康 App 把 iPhone 和手表的合好了，不会算两遍）
        private func readSteps(from: Date, to: Date) async throws -> [HealthSnapshot.Step] {
            let anchor = Calendar.current.dateInterval(of: .hour, for: from)?.start ?? from
            let range = HKQuery.predicateForSamples(withStart: from, end: to)
            let query = HKStatisticsCollectionQueryDescriptor(
                predicate: .quantitySample(type: HKQuantityType(.stepCount), predicate: range),
                options: .cumulativeSum, anchorDate: anchor, intervalComponents: DateComponents(hour: 1))
            let collection = try await query.result(for: store)
            return collection.statistics().compactMap { hour in
                let count = hour.sumQuantity()?.doubleValue(for: .count()) ?? 0
                return count >= 1 ? HealthSnapshot.Step(start: hour.startDate, count: Int(count.rounded())) : nil
            }
        }

        private func readSleep(from: Date, to: Date) async throws -> [HealthSnapshot.Sleep] {
            let range = HKQuery.predicateForSamples(withStart: from, end: to)
            let query = HKSampleQueryDescriptor(
                predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: range)],
                sortDescriptors: [SortDescriptor(\.startDate)])
            return try await query.result(for: store).map { sample in
                HealthSnapshot.Sleep(
                    start: sample.startDate, end: sample.endDate, stage: Self.stage(sample.value))
            }
        }

        private func readWorkouts(from: Date, to: Date) async throws -> [HealthSnapshot.Workout] {
            let range = HKQuery.predicateForSamples(withStart: from, end: to)
            let query = HKSampleQueryDescriptor(
                predicates: [.workout(range)], sortDescriptors: [SortDescriptor(\.startDate)])
            return try await query.result(for: store).map { workout in
                HealthSnapshot.Workout(
                    id: workout.uuid.uuidString, activity: Self.activity(workout.workoutActivityType),
                    start: workout.startDate, end: workout.endDate, minutes: workout.duration / 60,
                    kilometers: Self.kilometers(workout))
            }
        }

        /// 距离：走路跑步、骑车、游泳，哪种有用哪种
        private static func kilometers(_ workout: HKWorkout) -> Double? {
            let kinds: [HKQuantityTypeIdentifier] = [.distanceWalkingRunning, .distanceCycling, .distanceSwimming]
            for kind in kinds {
                if let sum = workout.statistics(for: HKQuantityType(kind))?.sumQuantity() {
                    return sum.doubleValue(for: .meterUnit(with: .kilo))
                }
            }
            return nil
        }

        /// 睡眠的一段是哪种：在床上、醒着，别的（深睡、核心、快速眼动、没分的）都是睡着
        static func stage(_ value: Int) -> String {
            switch HKCategoryValueSleepAnalysis(rawValue: value) {
            case .inBed: "inBed"
            case .awake: "awake"
            default: "asleep"
            }
        }

        /// 健康 App 的运动种类 → 服务器认得的名字（shared/src/health-app.ts 的 ACTIVITIES）
        static func activity(_ type: HKWorkoutActivityType) -> String {
            let names: [HKWorkoutActivityType: String] = [
                .running: "running", .walking: "walking", .hiking: "hiking", .cycling: "cycling",
                .swimming: "swimming", .yoga: "yoga", .traditionalStrengthTraining: "strength",
                .functionalStrengthTraining: "strength", .highIntensityIntervalTraining: "hiit", .coreTraining: "core",
                .elliptical: "elliptical", .rowing: "rowing", .stairClimbing: "stairs", .stairs: "stairs",
                .stepTraining: "stairs", .socialDance: "dance", .cardioDance: "dance", .badminton: "badminton",
                .basketball: "basketball", .soccer: "soccer", .tableTennis: "tableTennis", .tennis: "tennis",
                .jumpRope: "jumpRope", .pilates: "pilates", .flexibility: "stretching",
            ]
            return names[type] ?? "other"
        }
    }
#endif
