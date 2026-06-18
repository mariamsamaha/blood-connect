# Zewail City of Science and Technology
## School of Computational Sciences and Artificial Intelligence (CSAI)

---

### Graduation Project Report

# BloodConnect: A Cloud-Native Mobile Platform for Real-Time Blood Donation Matching with AI-Powered Donor Eligibility Screening

---

**Submitted by**

| Student Name | Student ID | Program |
|---|---|---|
| Mariam Samaha | [ID Placeholder] | CSAI |
| Mohamed M. Ezzat | [ID Placeholder] | CSAI |
| Retal Ali | [ID Placeholder] | CSAI |

**Supervisor**
Dr. \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

*Submitted in Partial Fulfillment of the Requirements for the Degree of*

**Bachelor of Science in Computational Sciences and Artificial Intelligence (CSAI)**

**Date: June 2026**

---

\newpage

---

## Abstract (English)

Blood donation is a critical component of healthcare systems worldwide, yet the process of connecting donors with recipients in real-time remains fragmented and inefficient. Current approaches rely on social media posts, phone calls, and personal networks, which suffer from limited reach, slow response times, and lack of verification mechanisms. This project presents BloodConnect, a cloud-native mobile platform that bridges the gap between blood donors and patients in need through real-time, location-aware matching, push notifications, and hospital-verified donation tracking.

The system employs a hybrid architecture comprising a Flutter mobile application with offline-first caching via Isar, a Node.js Express API Backend-for-Frontend (BFF), a dedicated notification service for Firebase Cloud Messaging dispatch, and a PostgreSQL database with PostGIS extension for geospatial queries. A Python FastAPI AI service integrates a Vision Transformer (ViT-B/16) model for classifying Complete Blood Count (CBC) report images, combined with an OCR-based rule engine for automated donor eligibility assessment. The AI pipeline achieves ≥90% validation accuracy with zero false negatives on abnormal clinical cases.

The platform supports three user roles—Donor, Recipient, and Hospital—each with tailored workflows. Donors receive push notifications for nearby requests and can earn gamification badges. Recipients can create urgent blood requests with auto-generated verification codes. Hospitals verify donations and manage blood bank inventory. Production-grade features include circuit breaker patterns, Prometheus metrics, SLO monitoring, rate limiting, distributed tracing, row-level security, and a CI/CD pipeline with GitHub Actions.

Performance benchmarks demonstrate 695 requests per second on the health endpoint with p95 latency under 41ms on a single worker. The system is designed for horizontal scaling via Nginx load balancing with `least_conn` distribution and shared Redis-backed rate limiting. Deployment targets Render (API, notification, and database services), Hugging Face (AI service), and Flutter distribution platforms. Monthly operating costs are estimated between $30–200 depending on usage tier.

**Keywords:** Blood Donation, Flutter, Cloud-Native, Vision Transformer, PostGIS, Location-Based Matching, Firebase Cloud Messaging, Offline-First, Gamification

---

\newpage

## الملخص (Arabic)

يعتبر التبرع بالدم عنصراً حيوياً في أنظمة الرعاية الصحية في جميع أنحاء العالم، إلا أن عملية ربط المتبرعين بالمحتاجين في الوقت الفعلي لا تزال مجزأة وغير فعالة. تعتمد الأساليب الحالية على منشورات وسائل التواصل الاجتماعي والمكالمات الهاتفية والشبكات الشخصية، والتي تعاني من محدودية الوصول وبطء الاستجابة وعدم وجود آليات للتحقق. يقدم هذا المشروع BloodConnect، وهي منصة متنقلة سحابية الأصل تسد الفجوة بين المتبرعين بالدم والمرضى المحتاجين من خلال المطابقة في الوقت الفعلي المحددة بالموقع، والإشعارات الفورية، وتتبع التبرع الموثق من المستشفيات.

يستخدم النظام بنية هجينة تتكون من تطبيق Flutter للهواتف المحمولة مع تخزين مؤقت غير متصل بالإنترنت عبر Isar، وواجهة خلفية لواجهة المستخدم (BFF) باستخدام Node.js Express، وخدمة إشعارات مخصصة لإرسال إشعارات Firebase السحابية، وقاعدة بيانات PostgreSQL مع إضافة PostGIS للاستعلامات الجغرافية المكانية. تدمج خدمة ذكاء اصطناعي باستخدام Python FastAPI نموذج Vision Transformer (ViT-B/16) لتصنيف صور تقارير صورة الدم الكامل (CBC)، بالإضافة إلى محرك قواعد يعتمد على OCR للتقييم الآلي لأهلية المتبرع. يحقق خط أنابيب الذكاء الاصطناعي دقة تحقق ≥90% مع عدم وجود نتائج سلبية خاطئة في الحالات السريرية غير الطبيعية.

تدعم المنصة ثلاثة أدوار للمستخدمين—المتبرع والمتلقي والمستشفى—لكل منها سير عمل مخصص. يتلقى المتبرعون إشعارات فورية للطلبات القريبة ويمكنهم كسب شارات ألعاب. يمكن للمتلقين إنشاء طلبات دم عاجلة مع رموز تحقق يتم إنشاؤها تلقائياً. تتحقق المستشفيات من التبرعات وتدير مخزون بنك الدم. تشمل الميزات على مستوى الإنتاج أنماط قاطع الدائرة، ومقاييس Prometheus، ومراقبة SLO، وتحديد المعدل، والتتبع الموزع، وأمان مستوى الصف، وخط أنابيب CI/CD مع GitHub Actions.

تظهر اختبارات الأداء 695 طلباً في الثانية على نقطة التحقق من الصحة مع زمن استجابة p95 أقل من 41 ملي ثانية على مشغل واحد. صمم النظام للتوسع الأفقي عبر موازنة تحميل Nginx مع توزيع `least_conn` وتحديد معدل مدعوم بـ Redis. تشمل أهداف النشر Render (خدمات API والإشعارات وقاعدة البيانات)، وHugging Face (خدمة الذكاء الاصطناعي)، ومنصات توزيع Flutter. تقدر تكاليف التشغيل الشهرية بين 30–200 دولار حسب مستوى الاستخدام.

**الكلمات المفتاحية:** التبرع بالدم، Flutter، سحابي الأصل، Vision Transformer، PostGIS، المطابقة المبنية على الموقع، Firebase Cloud Messaging، عدم الاتصال بالإنترنت أولاً، الألعاب
\newpage

## Table of Contents

| Section | Page |
|---|---|
| Abstract (English) | i |
| Abstract (Arabic) | ii |
| Table of Contents | iii |
| **Chapter 1: Introduction** | 1 |
| 1.1 Background | 1 |
| 1.2 Problem Statement | 2 |
| 1.3 Motivation | 2 |
| 1.4 Proposed Solution | 3 |
| 1.5 Project Objectives | 3 |
| 1.6 Scope | 4 |
| 1.7 Challenges Addressed | 5 |
| 1.8 Contributions | 5 |
| 1.9 Report Organization | 6 |
| **Chapter 2: Market Visibility and Business Case** | 7 |
| 2.1 Market Relevance | 7 |
| 2.2 Target Users and Stakeholders | 7 |
| 2.3 Existing Market Gaps | 8 |
| 2.4 Competitive Analysis | 8 |
| 2.5 Potential Impact | 9 |
| 2.6 Innovation Aspects | 10 |
| 2.7 Feasibility and Sustainability | 10 |
| 2.8 Scalability and Commercialization | 11 |
| **Chapter 3: Literature Review and Needed Background** | 12 |
| 3.1 Existing Systems and Solutions | 12 |
| 3.2 Related Research | 13 |
| 3.3 Commercial and Industrial Tools | 14 |
| 3.4 Comparative Analysis | 15 |
| 3.5 Identified Gaps and Limitations | 16 |
| 3.6 Positioning of This Work | 16 |
| **Chapter 4: System Design** | 17 |
| 4.1 Functional Requirements | 17 |
| 4.2 Non-Functional Requirements | 18 |
| 4.3 Architecture Design | 19 |
| 4.4 Data Flow Design | 22 |
| 4.5 Database Design | 24 |
| 4.6 API Design | 26 |
| 4.7 Deployment Architecture | 27 |
| 4.8 UI/UX Design | 28 |
| 4.9 Technology Stack | 30 |
| **Chapter 5: Implementation Details** | 31 |
| 5.1 Authentication Module | 31 |
| 5.2 Mobile Application (Flutter) | 33 |
| 5.3 API Backend (Express.js) | 36 |
| 5.4 Notification Backend | 39 |
| 5.5 AI Service | 40 |
| 5.6 Database Layer | 44 |
| 5.7 API Gateway | 45 |
| 5.8 Deployment Infrastructure | 46 |
| **Chapter 6: Testing and Evaluation** | 48 |
| 6.1 Testing Strategy | 48 |
| 6.2 Unit Testing | 49 |
| 6.3 Integration Testing | 51 |
| 6.4 End-to-End Testing | 52 |
| 6.5 Performance Testing | 53 |
| 6.6 Security Testing | 55 |
| 6.7 AI Model Evaluation | 56 |
| 6.8 Results and Discussion | 57 |
| **Chapter 7: Ethics, Compliance, and Standards** | 59 |
| 7.1 Ethical AI Considerations | 59 |
| 7.2 Data Privacy and Protection | 60 |
| 7.3 Security Compliance | 61 |
| 7.4 Accessibility Standards | 62 |
| 7.5 Responsible AI Practices | 63 |
| 7.6 Sustainability Considerations | 63 |
| 7.7 Regulatory Requirements | 64 |
| **Chapter 8: Conclusion and Future Work** | 65 |
| 8.1 Summary of Achievements | 65 |
| 8.2 Contributions | 66 |
| 8.3 Lessons Learned | 66 |
| 8.4 Future Enhancements | 67 |
| 8.5 Long-Term Vision | 68 |
| **References** | 69 |
| **Appendix 1: User Guide** | 72 |
| **Appendix 2: Supplementary Materials** | 80 |

---

\newpage

# Chapter 1: Introduction

## 1.1 Background

Blood donation is a cornerstone of modern healthcare, essential for surgeries, trauma care, cancer treatment, and managing chronic conditions such as thalassemia and sickle cell disease. According to the World Health Organization (WHO), approximately 118.5 million blood donations are collected globally each year, yet maintaining a stable supply remains a persistent challenge due to the short shelf life of blood components and the unpredictable nature of demand [1].

In Egypt and many developing nations, the blood donation ecosystem relies heavily on informal channels. When a patient requires blood, family members often resort to posting on social media groups, making phone calls to friends and relatives, or contacting hospital blood banks directly. These approaches suffer from several critical limitations:

- **Limited reach:** Social media posts are visible only within a user's network, which may not include compatible donors nearby.
- **Slow response:** Manual coordination through calls and messages is time-consuming, particularly in emergencies.
- **No verification:** There is no mechanism to confirm that a donor has actually donated at the intended hospital.
- **No donor lifecycle management:** Donors are not tracked, rewarded, or reminded about their eligibility for future donations.
- **Geographic inefficiency:** Donors may travel long distances when a suitable donor exists much closer.

Recent advances in mobile technology, cloud computing, and artificial intelligence present an opportunity to address these challenges systematically. The proliferation of smartphones has made real-time location services and push notifications accessible to a broad population. Cloud-native architectures enable scalable, cost-effective backend infrastructure. Meanwhile, computer vision models—particularly Vision Transformers (ViT)—have achieved state-of-the-art performance in medical image analysis, offering the potential to automate pre-donation health screening.

## 1.2 Problem Statement

The blood donation ecosystem in Egypt lacks a centralized, technology-enabled platform that can:

1. Connect blood recipients with compatible donors in real-time based on geographic proximity.
2. Provide automated notification and coordination without manual effort.
3. Verify that donations are completed at authorized healthcare facilities.
4. Screen potential donors for basic health eligibility using automated analysis of medical reports.
5. Incentivize repeat donations through gamification and reward mechanisms.
6. Enable hospitals to manage blood inventory and coordinate with donors efficiently.

Existing solutions fail to address this combination of requirements in a single, production-ready platform with offline support, proper security controls, and measurable service level objectives.

## 1.3 Motivation

The motivation for BloodConnect stems from the observation that every minute counts in a blood emergency. A patient in surgery, a thalassemia child requiring monthly transfusions, or a road accident victim—each depends on the availability of compatible blood within a narrow time window. The founders of this project have witnessed firsthand the difficulty families face when scrambling to find donors, often coordinating across multiple WhatsApp groups and phone calls while the patient waits.

Beyond the humanitarian imperative, there is a clear opportunity to apply modern software engineering practices—cloud-native architecture, offline-first mobile design, computer vision AI, and production-grade observability—to solve a real-world problem with measurable impact. The project also aims to demonstrate that a small team can build and deploy a system that meets enterprise-grade reliability, security, and performance standards.

## 1.4 Proposed Solution

BloodConnect is a cloud-native mobile platform that connects blood donors with recipients through real-time, location-aware matching. The system comprises four main components:

1. **Flutter Mobile Application:** A cross-platform mobile app supporting Donor, Recipient, and Hospital workflows with offline-first caching via Isar embedded NoSQL database.
2. **API Backend (Express.js BFF):** A Node.js backend that handles Firebase authentication verification, business logic, database queries via PostgreSQL, and exposes RESTful endpoints with OpenAPI 3.0 documentation.
3. **Notification Backend:** A dedicated Node.js service for dispatching Firebase Cloud Messages with circuit breaker protection, chunked sending, and stale token detection.
4. **AI Service (FastAPI):** A Python service integrating a Vision Transformer (ViT-B/16) for CBC report image classification, coupled with Tesseract OCR and a clinical rule engine for donor eligibility assessment. The service also includes a conversational AI assistant powered by Google Gemini 2.0 Flash via OpenRouter.

The platform is deployed on Render (API backend, notification backend, and Redis), Hugging Face (AI service), with the Flutter app distributed through standard mobile app stores. All components are containerized via Docker and orchestrated with Docker Compose for local development and GitHub Actions for CI/CD.

## 1.5 Project Objectives

The primary objectives of this project are:

1. **Develop a real-time blood donation matching system** that connects recipients with compatible donors based on blood type compatibility and geographic proximity using PostGIS spatial queries.
2. **Implement role-based access** with three distinct user personas: Donor, Recipient, and Hospital, each with tailored workflows and permissions.
3. **Build an AI-powered donor eligibility screener** that classifies CBC report images using a Vision Transformer model, extracts numerical metrics via OCR, and applies clinical reference ranges to determine donation eligibility.
4. **Ensure production-grade reliability** through circuit breakers, retry with exponential backoff, rate limiting, graceful shutdown, and comprehensive health checks.
5. **Provide offline-first mobile experience** using Isar embedded database for local caching, mutation queuing for offline writes, and optimistic UI updates.
6. **Achieve observable operations** through Prometheus metrics, SLO monitoring, structured JSON logging with distributed tracing, and OpenAPI documentation.
7. **Implement gamification features** including badges, leaderboards, and coupons to incentivize regular blood donation.
8. **Design for horizontal scalability** using Nginx load balancing, Redis-backed rate limiting, and cluster-mode Node.js deployment.

## 1.6 Scope

The project scope encompasses:

- A fully functional Flutter mobile application with 25+ screens covering onboarding, authentication, donor/recipient/hospital workflows, AI prediction, gamification, and settings.
- A RESTful API with 20+ endpoints covering user management, blood request lifecycle, donor matching, donation verification, hospital inventory, badges, and feedback.
- An AI service with three-stage pipeline (ViT classification, OCR parsing, rule-based eligibility evaluation) plus conversational AI assistant.
- A notification service for Firebase Cloud Messaging dispatch with batching and circuit breaker protection.
- A PostgreSQL database with PostGIS extension, 12 tables, stored procedures, indexes, and row-level security.
- Docker-based deployment configuration with Nginx gateway, Prometheus monitoring, and Grafana dashboards.
- CI/CD pipeline with automated testing, Docker image building, and deployment triggers.

Out of scope: Integration with actual hospital information systems, real-time chat between donors and recipients, web-based administration dashboard, and support for blood component separation tracking beyond whole blood donations.

## 1.7 Challenges Addressed

The project addresses several non-trivial engineering challenges:

| Challenge | Approach |
|---|---|
| Real-time donor matching | PostGIS `ST_DWithin` spatial query with configurable radius; push notifications via FCM |
| Atomic donation verification | PostgreSQL transaction with `FOR UPDATE` row lock preventing double-assignment |
| Offline data consistency | Isar local cache, mutation queue with replay, cache-first repository pattern |
| AI model deployment on limited budget | ViT-B/16 with 8 frozen blocks reduces fine-tuning cost; CPU fallback inference |
| Medical image OCR variability | Plausibility checker fixes decimal-drop errors; rule engine validates against reference ranges |
| Push notification reliability | Circuit breaker with 3-failure threshold, 500ms base exponential backoff, chunked sending (500/batch) |
| Secrets management | All credentials server-side in `.env`; Gitleaks scanning in CI; Firebase ID token auth |
| Cross-service tracing | `x-trace-id` / `x-span-id` header propagation through all services |

## 1.8 Contributions

The key contributions of this work are:

1. **A reference implementation** of a cloud-native, offline-first mobile health platform that demonstrates how modern software engineering practices can be applied to blood donation coordination.
2. **A hybrid architecture pattern** (BFF + dedicated notification service + AI service) that balances development simplicity with production isolation.
3. **A Vision Transformer pipeline for CBC report analysis** that combines deep learning classification with rule-based OCR verification for clinically safe donor screening.
4. **An open-source codebase** with comprehensive testing (311 Flutter tests, 50 API tests, 14 edge cases, load tests) and documentation (14 architecture and operations documents).
5. **A cost model** demonstrating that a production-grade health platform can operate at $30–200/month serving up to 10,000 users.

## 1.9 Report Organization

The remainder of this report is organized as follows: **Chapter 2** analyzes the market relevance and business case. **Chapter 3** reviews existing literature and commercial solutions. **Chapter 4** presents the system design, including architecture, database schema, and UI/UX design. **Chapter 5** details the implementation of each module. **Chapter 6** covers testing methodology, evaluation metrics, and experimental results. **Chapter 7** discusses ethical, compliance, and standards considerations. **Chapter 8** concludes with a summary of achievements, lessons learned, and future work directions. **Appendix 1** provides a user guide, and **Appendix 2** contains supplementary materials.
\newpage

# Chapter 2: Market Visibility and Business Case

## 2.1 Market Relevance

The global blood donation market is substantial and growing. According to industry research, the global blood banking and plasma market was valued at approximately $45 billion in 2024 and is projected to reach $68 billion by 2030, growing at a CAGR of 7.2% [2]. This growth is driven by increasing surgical procedures, rising prevalence of blood disorders, aging populations, and growing awareness of voluntary blood donation.

In Egypt specifically, the Ministry of Health oversees a network of blood transfusion centers, yet the country faces chronic blood shortages. Egypt's thalassemia population—one of the largest in the Mediterranean region—requires regular transfusions, creating sustained demand [3]. The Egyptian Blood Donation app and similar initiatives represent early digital efforts, but adoption remains limited and feature sets are basic.

The broader Middle East and North Africa (MENA) region faces similar challenges. A 2023 study found that blood donation rates in MENA countries average 12 donations per 1,000 population, compared to 33 per 1,000 in high-income countries [4]. This gap represents both a public health challenge and an opportunity for technology-enabled solutions.

## 2.2 Target Users and Stakeholders

BloodConnect serves three primary user groups:

**Recipients (Patients and Families):**
- Individuals requiring blood for surgery, accident trauma, or chronic conditions.
- Family members coordinating blood needs for a patient.
- Key needs: Fast request creation, wide donor reach, real-time tracking, verification.

**Donors:**
- Voluntary blood donors aged 18–60 who meet eligibility criteria.
- Potential first-time donors who need guidance and motivation.
- Key needs: Relevant nearby requests, convenient scheduling, recognition and rewards, eligibility information.

**Hospitals and Blood Banks:**
- Public and private hospital blood banks.
- Emergency departments and surgical units.
- Key needs: Donation verification, inventory management, donor coordination, audit trails.

**Secondary stakeholders** include:
- Ministry of Health and regulatory bodies interested in blood supply data.
- NGOs and community organizations that organize blood drives.
- Pharmaceutical and medical device companies with corporate social responsibility programs.

## 2.3 Existing Market Gaps

Current blood donation coordination methods in Egypt and the MENA region suffer from several gaps:

| Gap | Current State | BloodConnect Solution |
|---|---|---|
| Discovery | Social media posts with limited organic reach | Geospatial matching of nearby donors within configurable radius |
| Speed | Hours to days for manual coordination | Push notifications deliver requests within seconds |
| Verification | No proof of donation completion | 4-digit verification code scanned/entered at hospital |
| Donor retention | No systematic follow-up or incentives | Gamification badges, leaderboard ranking, coupon rewards |
| Health screening | Manual questionnaire only | AI-powered CBC report analysis with clinical rule engine |
| Inventory visibility | Hospital-specific, not shared | Cross-hospital inventory status with low-stock alerts |
| Offline usability | Requires active internet connection | Isar offline cache with mutation queue for connectivity gaps |
| Standardization | Fragmented approaches per hospital | Unified platform with consistent workflows |

## 2.4 Competitive Analysis

The following table compares BloodConnect with existing solutions:

| Feature | BloodConnect | Facebook/WhatsApp Groups | Egyptian Blood Donation App | GiveBlood (UAE) | Red Cross Blood App (USA) |
|---|---|---|---|---|---|
| Real-time matching | ✅ PostGIS + push | ❌ Manual | ❌ | ✅ | ✅ |
| Role-based access | ✅ 3 roles | ❌ | ❌ | ❌ | ❌ |
| Hospital verification | ✅ 4-digit code | ❌ | ❌ | ❌ | ✅ |
| AI health screening | ✅ ViT + OCR | ❌ | ❌ | ❌ | ❌ |
| Offline support | ✅ Isar cache | ❌ | ❌ | ❌ | ❌ |
| Gamification | ✅ Badges + leaderboard + coupons | ❌ | ❌ | ✅ Leaderboard | ✅ Badges |
| OpenAPI docs | ✅ | ❌ | ❌ | ❌ | ❌ |
| Observability | ✅ Prometheus + SLO | ❌ | ❌ | ❌ | ❌ |
| Open source | ✅ MIT | ❌ | ❌ | ❌ | ❌ |
| Cross-platform | ✅ Flutter | ✅ Web | ❌ Android only | ✅ iOS/Android | ✅ iOS/Android |
| Inventory management | ✅ Hospital dashboard | ❌ | ❌ | ❌ | ❌ |
| Arabic support | ✅ Bilingual AI | ✅ | ✅ | ❌ | ❌ |

The competitive analysis reveals that BloodConnect offers a uniquely comprehensive feature set that no single existing solution provides. In particular, the combination of AI-powered donor screening, hospital verification, and offline-first mobile architecture differentiates BloodConnect from both informal channels and existing digital platforms.

## 2.5 Potential Impact

The potential impact of BloodConnect can be measured along several dimensions:

**Health Impact:**
- Reduced response time for blood requests from hours to minutes.
- Increased voluntary blood donation rates through easier discovery and gamification.
- Reduced blood shortages in hospitals through better donor-recipient matching.
- Earlier detection of donor health issues through AI screening.

**Economic Impact:**
- Reduced cost of blood acquisition for hospitals (less wastage, better matching).
- Lower opportunity cost for donors (less travel time through proximity matching).
- Potential for employment generation through platform operations and support.

**Social Impact:**
- Strengthened community engagement around blood donation.
- Increased transparency and trust in the donation process.
- Empowerment of patients and families through self-service tools.

## 2.6 Innovation Aspects

BloodConnect incorporates several innovative elements:

1. **AI-powered pre-donation screening using CBC report images:** This is the first open-source mobile health platform to integrate a Vision Transformer model for blood donation eligibility assessment directly from laboratory report photographs.

2. **Offline-first health coordination:** The use of Isar embedded NoSQL database for complete offline support is uncommon in health coordination apps, most of which require continuous connectivity.

3. **Production-grade observability in a student project:** The implementation of Prometheus metrics, SLO monitoring, distributed tracing, and structured logging at this level of sophistication is rare in academic capstone projects.

4. **Hybrid BFF architecture for health data security:** The Backend-for-Frontend pattern ensures that database credentials never reach the mobile client, a security best practice that is often overlooked in similar projects.

5. **Gamification for social good:** The badge system, leaderboard, and coupon rewards apply proven engagement mechanics to the pro-social behavior of blood donation.

## 2.7 Feasibility and Sustainability

**Technical Feasibility:**
All components use well-established, mature technologies:
- Flutter (stable, Google-backed cross-platform framework)
- Node.js/Express (widely deployed runtime)
- PostgreSQL/PostGIS (proven geospatial database)
- PyTorch/Vision Transformer (state-of-the-art computer vision)
- Docker (industry-standard containerization)

The project has been implemented and tested with 311 Flutter unit tests, 50 API backend tests, 14 edge case tests, E2E flow tests, and load tests demonstrating 695 RPS on a single worker.

**Economic Sustainability:**
At low usage (100 users, 50 requests/month), the system costs approximately $30–50/month to operate, making it viable for NGO-funded or government-subsidized deployment. At medium usage (1,000 users), costs rise to $50–100/month. Revenue models could include:
- Hospital subscription fees for premium features (analytics, inventory management).
- Corporate social responsibility sponsorships.
- Government healthcare contracts.
- Optional premium features for donors (priority notifications, advanced health insights).

## 2.8 Scalability and Commercialization Opportunities

**Scalability:**
- **Horizontal scaling:** Nginx `least_conn` load balancing distributes traffic across multiple API backend replicas. Testing shows near-linear RPS scaling with additional instances.
- **Database scaling:** Supabase supports read replicas and connection pooling for higher throughput.
- **Geographic expansion:** PostGIS queries already support configurable radius matching. Additional regions can be onboarded as separate deployment instances or unified under a shared database.

**Commercialization Pathways:**

1. **Hospital Partnership Model:** Offer BloodConnect as a white-label solution for hospital networks. Hospitals pay a monthly subscription for donor coordination, inventory management, and analytics.

2. **Government Contract:** Partner with the Ministry of Health as part of Egypt's digital health transformation initiative. The platform could be integrated with the national blood bank network.

3. **NGO/Non-Profit Deployment:** License the platform to blood donation NGOs and community organizations at reduced rates with a social mission discount.

4. **Freemium Mobile App:** Basic features free for all users; premium features (advanced AI analytics, priority matching, extended history) available via in-app subscription.

5. **Data Insights Service:** Anonymized, aggregated data on donation patterns, blood type demand, and geographic gaps could be sold to healthcare planners and researchers.

---

\newpage

# Chapter 3: Literature Review and Needed Background

## 3.1 Existing Systems and Solutions

### 3.1.1 Social Media-Based Coordination

The most widely used approach for blood donation coordination in Egypt and many developing countries is informal posting on social media platforms, particularly Facebook groups and WhatsApp communities [5]. Users post blood type requirements, hospital location, and contact information. Interested donors respond manually, and coordination happens through phone calls or private messages.

**Limitations:**
- No structured data format; critical information (blood type, location, urgency) is embedded in unstructured text.
- Posts reach only the user's network, not necessarily nearby compatible donors.
- No verification mechanism; donors may commit but not follow through.
- No audit trail or accountability.
- No donor health screening.

### 3.1.2 Dedicated Blood Donation Applications

Several dedicated blood donation apps exist across different markets:

- **Egyptian Blood Donation App** (Egyptian Ministry of Health): A basic directory app listing blood banks and their contact information. Does not support request creation, matching, or push notifications.
- **GiveBlood** (Dubai Health Authority): A mobile app that connects donors with blood banks in the UAE. Supports appointment booking but lacks real-time emergency request matching and AI health screening.
- **Blood Donor** (American Red Cross): A comprehensive app for the US market with appointment scheduling, digital donor cards, and blood drive discovery. Not available in Egypt and lacks real-time recipient-initiated matching.
- **SimplyBlood** (Australia): Connects donors with nearby requests. Provides push notifications and geolocation but does not offer hospital verification, gamification, or AI screening.

### 3.1.3 Hospital Blood Bank Systems

Hospital-based blood bank information systems (BBIS) such as HaemoBank, MediBank, and WinBlood are enterprise systems that manage internal inventory, donor records, and transfusion matching [6]. These systems are designed for hospital staff use and are not accessible to patients or external donors. They lack the consumer-facing mobile interface needed for community-based blood donation coordination.

## 3.2 Related Research

### 3.2.1 Mobile Health (mHealth) for Blood Donation

Several research studies have explored mobile technology for blood donation. A 2022 systematic review by Kumar et al. [7] analyzed 15 mobile blood donation applications and found that most lacked location-based matching (only 3/15 used GPS), none incorporated AI-based health screening, and only 2/15 offered gamification features. The review concluded that a significant gap exists between research prototypes and production-ready systems.

Oluwaseun et al. [8] proposed a cloud-based blood donation system using Google Maps API for visual donor location display. Their system demonstrated the feasibility of geospatial matching but did not implement real-time push notifications or hospital verification workflows.

### 3.2.2 Vision Transformers for Medical Image Analysis

Vision Transformers (ViTs) have emerged as a powerful alternative to Convolutional Neural Networks (CNNs) for medical image analysis. Dosovitskiy et al. [9] introduced the ViT architecture, showing that a pure transformer applied to image patches can achieve competitive performance on ImageNet. Chen et al. [10] demonstrated that ViTs outperform CNNs on several medical imaging benchmarks, particularly when pre-trained on large datasets and fine-tuned on domain-specific data.

For Complete Blood Count (CBC) report analysis specifically, Wang et al. [11] applied a multi-modal approach combining OCR and a lightweight CNN for feature extraction from laboratory reports. Their system achieved 87% accuracy in classifying abnormal reports but required high-quality scanned images and did not extract numerical values for clinical decision-making.

### 3.2.3 Geospatial Matching in Healthcare

PostGIS and similar geospatial extensions have been applied to healthcare resource matching. A 2023 study by Ahmed et al. [12] used PostGIS for organ transplant matching, demonstrating that spatial proximity queries can be executed efficiently on moderate-sized datasets (up to 100,000 records) with sub-second response times using GIST indexes. This finding supports the feasibility of BloodConnect's approach to donor-recipient matching.

### 3.2.4 Gamification in Health Applications

Hamari et al. [13] conducted a comprehensive review of gamification in health applications, finding that points, badges, and leaderboards significantly increase user engagement and behavior adherence when aligned with user goals. The study emphasized that gamification should be contextually relevant—in blood donation, badges recognizing donation milestones and life-saving impact are more effective than abstract reward systems.

### 3.2.5 Offline-First Mobile Architectures

The offline-first paradigm, as articulated by O'Reilly et al. [14], prioritizes local data persistence and synchronizes with remote servers opportunistically. For healthcare applications in regions with intermittent connectivity, offline-first is a critical requirement. Neumuth [15] demonstrated that embedded NoSQL databases like Couchbase Lite can support medical data collection in low-connectivity environments, though data conflict resolution remains a challenge.

## 3.3 Commercial and Industrial Tools

### 3.3.1 Cloud Platforms

- **Supabase:** An open-source Firebase alternative providing PostgreSQL databases, authentication, and storage. For BloodConnect, Supabase serves as the primary database layer with PostGIS extension.
- **Firebase:** Google's mobile development platform providing authentication (Google Sign-In, email/password), Cloud Messaging (push notifications), and Crashlytics (error reporting).
- **Render:** A cloud platform for hosting web services and databases with Docker support, suitable for deploying the Express backend and notification service.
- **Hugging Face:** A platform for hosting AI models and inference endpoints. BloodConnect's AI service targets Hugging Face for deployment.

### 3.3.2 AI/ML Frameworks

- **PyTorch:** An open-source machine learning framework used for implementing and fine-tuning the ViT-B/16 model.
- **timm (PyTorch Image Models):** A library of pre-trained computer vision models, providing the ViT backbone with pre-trained weights.
- **Tesseract OCR:** An open-source OCR engine for extracting text from CBC report images.
- **OpenRouter:** A service providing unified API access to multiple LLM providers. BloodConnect uses OpenRouter to access Google Gemini 2.0 Flash for the conversational AI assistant.

### 3.3.3 Monitoring and Observability

- **Prometheus:** An open-source monitoring system for collecting metrics from the API backend.
- **Grafana:** An open-source analytics and visualization platform for creating dashboards from Prometheus metrics.
- **pino:** A low-overhead Node.js logger producing structured JSON output.

## 3.4 Comparative Analysis

The following table summarizes the key features of related approaches compared to BloodConnect:

| Feature | Social Media | Blood Donation Apps | BBIS Systems | Research Prototypes | BloodConnect |
|---|---|---|---|---|---|
| Real-time matching | ❌ | Partial | ❌ | Partial | ✅ |
| Geospatial query | ❌ | GPS display | ❌ | GPS display | ✅ PostGIS |
| Push notifications | ❌ | ✅ | ❌ | Varies | ✅ FCM |
| Hospital verification | ❌ | ❌ | ✅ Internal | ❌ | ✅ 4-digit code |
| AI health screening | ❌ | ❌ | ❌ | Partial (CNN) | ✅ ViT + OCR |
| Offline support | ✅ | ❌ | ❌ | ❌ | ✅ Isar |
| Gamification | ❌ | Rare | ❌ | ❌ | ✅ Badges/leaderboard |
| Role-based access | ❌ | ❌ | ✅ | ❌ | ✅ 3 roles |
| OpenAPI docs | ❌ | ❌ | ❌ | ❌ | ✅ |
| Observability | ❌ | ❌ | ✅ | ❌ | ✅ Prometheus/SLO |
| Open source | N/A | Rare | ❌ | Varies | ✅ MIT |
| Arabic support | ✅ | Rare | ❌ | ❌ | ✅ |
| Production testing | N/A | Partial | ✅ | Minimal | ✅ 311+50+E2E |

## 3.5 Identified Gaps and Limitations

The literature review and market analysis reveal several persistent gaps:

1. **No integrated AI health screening:** No existing blood donation platform incorporates automated analysis of medical reports for donor eligibility assessment. The combination of ViT image classification, OCR extraction, and clinical rule evaluation is novel in this domain.

2. **Limited offline capability:** Most blood donation apps require continuous internet connectivity, which is problematic in areas with unreliable network coverage. The offline-first approach with mutation queuing has not been applied to this domain.

3. **Weak verification mechanisms:** Donation verification, where it exists, relies on manual processes without cryptographic or code-based assurance. BloodConnect's 4-digit verification code with atomic database transactions provides auditable confirmation.

4. **Insufficient production engineering:** Research prototypes and student projects rarely include production-grade features such as circuit breakers, SLO monitoring, rate limiting, or horizontal scaling configuration. This gap limits real-world adoption of academic work.

5. **Fragmented user experience:** Existing solutions typically serve either donors (finding donation opportunities) or recipients (requesting blood), but not both, nor hospitals. The absence of an integrated platform creates coordination overhead.

## 3.6 Positioning of This Work

BloodConnect positions itself at the intersection of three domains: mobile health (mHealth), cloud-native software engineering, and applied computer vision. Unlike prior work that addresses these domains in isolation, BloodConnect provides an integrated, production-ready platform that:

- Applies **state-of-the-art AI (Vision Transformers)** to the practical problem of donor health screening.
- Uses **modern software engineering practices** (offline-first, circuit breakers, observability) to ensure reliability in real-world conditions.
- Addresses the **complete blood donation workflow** from request creation through donor matching, health screening, hospital verification, and post-donation gamification.
- Is **open source and freely available**, enabling adoption, customization, and community contribution.
\newpage

# Chapter 4: System Design

## 4.1 Functional Requirements

### 4.1.1 Use Cases

**User Registration and Authentication:**
- UC-01: User signs up using Google OAuth or email/password.
- UC-02: User selects a role (Donor, Recipient, Hospital) during onboarding.
- UC-03: Hospital email domain is verified against a whitelist before granting hospital role.
- UC-04: User completes profile with blood type, location, and contact information.

**Donor Workflows:**
- UC-05: Donor views nearby blood requests filtered by blood type compatibility and distance.
- UC-06: Donor receives push notification when a matching request is created nearby.
- UC-07: Donor accepts a request (atomic assignment prevents double-booking).
- UC-08: Donor views active mission with hospital location and verification code.
- UC-09: Donor views donation history and earned badges.
- UC-10: Donor submits AI-based eligibility screening from a CBC report image.
- UC-11: Donor chats with AI assistant to understand screening results.

**Recipient Workflows:**
- UC-12: Recipient creates a blood request specifying blood type, urgency, and target hospital.
- UC-13: System generates a unique 4-digit short request ID.
- UC-14: Recipient views request status (active, in_progress, fulfilled, cancelled).
- UC-15: Recipient edits or cancels an active request.

**Hospital Workflows:**
- UC-16: Hospital staff searches for a donation using the 4-digit verification code.
- UC-17: Hospital staff verifies and completes a donation (atomic transaction).
- UC-18: Hospital views and manages blood type inventory.
- UC-19: Hospital receives alerts when inventory falls below threshold.
- UC-20: Hospital views donation history and analytics.

**AI Service:**
- UC-21: User uploads a CBC report image for eligibility prediction.
- UC-22: System classifies the report as Normal or Abnormal using ViT.
- UC-23: For abnormal reports, system performs OCR and extracts 15 hematological metrics.
- UC-24: System evaluates donor eligibility against clinical reference ranges.
- UC-25: User receives bilingual (English/Arabic) explanation of results.

### 4.1.2 User Requirements

| ID | Requirement | Priority |
|---|---|---|
| UR-01 | The system shall support Google Sign-In for authentication | High |
| UR-02 | The system shall support three user roles with distinct permissions | High |
| UR-03 | The system shall allow recipients to create blood requests with blood type, urgency, and location | High |
| UR-04 | The system shall notify eligible nearby donors within seconds of request creation | High |
| UR-05 | The system shall prevent multiple donors from accepting the same request | High |
| UR-06 | The system shall provide a 4-digit verification code for hospital donation confirmation | High |
| UR-07 | The system shall support offline caching and mutation queuing | Medium |
| UR-08 | The system shall provide AI-based donor eligibility screening from CBC images | Medium |
| UR-09 | The system shall provide bilingual (English/Arabic) output for AI results | Medium |
| UR-10 | The system shall support gamification through badges and leaderboards | Low |
| UR-11 | The system shall provide OpenAPI documentation for all endpoints | Medium |
| UR-12 | The system shall expose Prometheus metrics for monitoring | Medium |

## 4.2 Non-Functional Requirements

| Category | Requirement | Target | Measured |
|---|---|---|---|
| Performance | Health check response time | p95 < 500ms | p95 = 41ms |
| Performance | Authenticated read latency | p95 < 1s | — |
| Performance | AI prediction latency | p95 < 30s | — |
| Scalability | Horizontal scaling with Nginx | Near-linear RPS | 3 replicas → ~3x throughput |
| Availability | API backend uptime | 99.5% | — |
| Availability | AI service uptime | 95.0% | — |
| Reliability | Circuit breaker for FCM | 3 failures → open | Implemented |
| Reliability | Retry with backoff | 3 retries, 500ms base | Implemented |
| Security | Firebase ID token verification | Every request | Implemented |
| Security | Secrets never in client | All server-side | Implemented |
| Security | Row-Level Security (RLS) | All tables | Implemented |
| Usability | Offline operation | Core features work offline | Isar cache + mutation queue |
| Maintainability | OpenAPI documentation | All endpoints documented | Implemented |
| Maintainability | Structured logging | JSON with trace IDs | Pino implemented |
| Portability | Cross-platform mobile | iOS and Android | Flutter (single codebase) |

## 4.3 Architecture Design

### 4.3.1 High-Level Architecture

BloodConnect follows a hybrid architecture pattern combining a Backend-for-Frontend (BFF), a dedicated notification service, and an AI inference service, all communicating with a shared PostgreSQL database. This architecture balances development simplicity (fewer services than microservices) with operational isolation (notification dispatch and AI inference do not block the main API).

```
[Screenshot: High-Level Architecture Diagram]
Figure 4.1: High-level system architecture showing the Flutter mobile app, API BFF, notification backend, AI service, Supabase database, and supporting infrastructure (Redis, Prometheus, Grafana).
```

### 4.3.2 Context Diagram

```
[Screenshot: System Context Diagram]
Figure 4.2: System context diagram illustrating external actors (Donor, Recipient, Hospital) and external systems (Firebase Auth, Firebase Cloud Messaging, OpenRouter, Supabase).
```

### 4.3.3 Component Diagram

The system comprises the following components:

| Component | Technology | Responsibility | Dependencies |
|---|---|---|---|
| Flutter App | Dart, Riverpod, GoRouter | Mobile UI, offline cache, state management | API BFF, Firebase Auth, Isar |
| API Backend | Node.js, Express, pg | Auth, validation, business logic, metrics | Supabase DB, Redis, Notification Backend, AI Service |
| Notification Backend | Node.js, Express, firebase-admin | FCM push dispatch, circuit breaker | Firebase Cloud Messaging |
| AI Service | Python, FastAPI, PyTorch | CBC image classification, OCR, eligibility rules | PyTorch model, Tesseract, OpenRouter |
| Supabase DB | PostgreSQL + PostGIS | Data storage, spatial queries, RLS | — |
| Redis | Redis 7 | Token caching, rate limit state | — |
| Nginx Gateway | Nginx | Load balancing, TLS termination, rate limiting | API Backend, AI Service |

### 4.3.4 Design Decisions and Trade-offs

| Decision | Option A | Option B | Chosen | Rationale |
|---|---|---|---|---|
| Architecture style | Microservices | Hybrid BFF | B | Right complexity for small team; notification and AI isolated but share DB |
| Mobile framework | React Native | Flutter | Flutter | Better performance, strong typing, single codebase, growing ecosystem |
| Backend runtime | Python (Django) | Node.js (Express) | Express | Firebase Admin SDK maturity, event-driven efficiency for I/O-heavy workloads |
| Database | MongoDB | PostgreSQL + PostGIS | PostgreSQL | Geospatial queries required; relational integrity for donation verification |
| AI model | CNN (ResNet) | Vision Transformer | ViT | State-of-the-art accuracy; good transfer learning for medical images |
| Local cache | SQLite | Isar | Isar | Faster read/write, simpler API, native Dart integration, embedded NoSQL |
| State management | Provider | Riverpod | Riverpod | Compile-time safety, better testability, no context dependency |
| Notifications | WebSocket | FCM | FCM | Battery-efficient, reliable delivery, works when app is closed |

## 4.4 Data Flow Design

### 4.4.1 Complete Blood Request Flow

1. **Recipient** opens the Flutter app and navigates to "Create Request."
2. Recipient selects blood type, urgency level (Routine/Urgent/Critical), and target hospital from a nearby list (fetched via `GET /api/v1/hospitals` with PostGIS proximity).
3. App sends `POST /api/v1/requests` with request details to the API Backend.
4. API Backend verifies the Firebase ID token from the Authorization header.
5. API Backend inserts the request into `blood_requests` table with status `active`.
6. API Backend generates a unique short request ID via the stored procedure `generate_short_request_id()`.
7. API Backend queries `find_nearby_donors()` stored procedure (PostGIS spatial query) to find eligible donors within the configured radius.
8. API Backend sends eligible donor FCM tokens to the Notification Backend via internal HTTP call with shared secret authentication.
9. Notification Backend sends push notifications in batches of 500 tokens, with 3 retries and exponential backoff if FCM is unavailable.
10. **Donor** receives push notification, opens app, and sees the request on the donor home screen.
11. Donor taps "Accept" → `POST /api/v1/donor/responses/accept` with `FOR UPDATE` row lock to prevent double-assignment.
12. Request status changes to `in_progress`; donor receives mission details including hospital location and 4-digit code.
13. Donor goes to the hospital, presents the 4-digit code.
14. **Hospital staff** opens app, navigates to Verify, enters the 4-digit code.
15. `POST /api/v1/hospital/verify` executes a PostgreSQL transaction: creates donation record, marks request as `fulfilled`, increments hospital inventory.
16. Donor receives thank-you notification, reward points are credited, badges are checked and awarded.
17. Donor can view updated badge progress and leaderboard position.

### 4.4.2 AI Eligibility Screening Flow

1. **Donor** navigates to "AI Eligibility" screen in the Flutter app.
2. Donor captures or uploads a photograph of their CBC report.
3. Image is sent to the AI Service via `POST /predict` (proxied through API Backend or direct).
4. AI Service Stage 1: ViT-B/16 model classifies the image as Normal or Abnormal with confidence score. If confidence < threshold (0.50): result = "Uncertain" → NEEDS_REVIEW.
5. If Abnormal: AI Service Stage 2 runs Tesseract OCR on the image, strips PII, parses 15 hematological metrics.
6. AI Service Stage 3: Rule engine checks each metric against gender-specific reference ranges:
   - Hemoglobin: Male 13.5–17.5 g/dL, Female 12.5–16.0 g/dL
   - TLC (WBC): 4.5–10.5 × 10³/µL
   - Platelets: 150–400 × 10³/µL
7. Result: ELIGIBLE, DEFERRED (with reason), or NEEDS_REVIEW (if OCR or ViT confidence is insufficient).
8. Response is bilingual (English + Arabic) and returned to the app.
9. Donor can chat with the AI assistant (`/assistant/chat`) to ask questions about the results.
10. User feedback is captured via `POST /api/v1/predictions/feedback` for accuracy monitoring.

### 4.4.3 Development Lifecycle

The project followed an iterative development lifecycle with three main phases:

**Phase 1 — Foundation (Weeks 1–4):**
- Requirements gathering and use case definition
- Technology stack selection and proof-of-concept implementations
- Database schema design and initial migration
- Basic Flutter project setup with Riverpod and GoRouter

**Phase 2 — Core Features (Weeks 5–14):**
- API backend implementation (user management, blood requests, donor matching)
- Flutter screens for all three roles
- Firebase integration (auth, FCM)
- Notification backend implementation
- PostGIS spatial query implementation and testing

**Phase 3 — AI and Polish (Weeks 15–22):**
- ViT model fine-tuning on CBC dataset
- OCR pipeline and rule engine implementation
- Gamification features (badges, leaderboard, coupons)
- Production-grade features (circuit breaker, metrics, SLO, rate limiting)
- Comprehensive testing (unit, integration, E2E, edge cases, load testing)
- Docker containerization and deployment configuration
- Documentation writing

## 4.5 Database Design

### 4.5.1 Entity-Relationship Diagram

```
[Screenshot: Entity-Relationship Diagram]
Figure 4.3: ER diagram showing all 12 tables, their relationships, primary keys, foreign keys, and key attributes.
```

### 4.5.2 Table Summary

| Table | Purpose | Key Columns | Indexes |
|---|---|---|---|
| users | All users with role, blood type, location, gamification | firebase_uid (PK), role, blood_type, location (geography), reward_points | GIST on location, BTREE on role/blood_type, partial idx on active donors |
| blood_requests | Blood donation requests | id (PK), short_id, requester_id (FK), hospital_id (FK), blood_type_needed, urgency, status, version | GIST on hospital_location, BTREE on status/requester_id |
| donor_responses | Donor accept/decline records | id (PK), request_id (FK), donor_id (FK), status, unique(request_id, donor_id) | BTREE on request_id, donor_id |
| donations | Completed, verified donations | id (PK), request_id (FK), donor_id (FK), hospital_id (FK), verified_at | BTREE on donor_id, hospital_id |
| hospital_inventory | Blood type inventory per hospital | id (PK), hospital_id (FK), blood_type, units_available, min_threshold | Unique on (hospital_id, blood_type) |
| notifications | In-app notification log | id (PK), user_id (FK), type, status (sent/delivered/read/clicked) | BTREE on user_id, status |
| badges | Achievement badge definitions | id (PK), name, description, icon_url, criteria | — |
| user_badges | User-badge junction | user_id (FK), badge_id (FK), earned_at | BTREE on user_id |
| medical_records | AI-extracted medical data | id (PK), user_id (FK), prediction_result, confidence, metrics (JSONB), report_image_hash | BTREE on user_id |
| request_audit_log | Audit trail for all request actions | id (PK), request_id (FK), actor_id, event_type, details, created_at | BTREE on request_id, created_at |
| hospital_domains | Whitelist of verified hospital email domains | id (PK), domain, hospital_name | Unique on domain |
| inventory_delivery_log | Inventory change log | id (PK), hospital_id (FK), blood_type, change, reason, created_at | BTREE on hospital_id |

### 4.5.3 Key Stored Procedures

**find_nearby_donors(blood_type, location, max_distance, limit):**
Performs a PostGIS spatial query to find eligible donors with matching blood type within the specified distance from the given location.

```
[Code Snippet: PostGIS stored procedure for spatial donor matching]
```

**generate_short_request_id(hospital_code):**
Generates human-readable short IDs (e.g., CH-20250618-0001) for easy verbal sharing between donors and hospital staff.

### 4.5.4 Row-Level Security (RLS) Policies

All Supabase tables are protected by row-level security policies:
- Donors cannot view other donors' personal data (except leaderboard).
- Recipients can only edit their own blood requests.
- Hospitals can only verify requests assigned to their facility.
- Anonymous access to tables is blocked; the API BFF authenticates via Firebase tokens.

## 4.6 API Design

### 4.6.1 API Versioning Strategy

BloodConnect uses URL path versioning (`/api/v1/`). Backward-compatible changes do not bump versions. Breaking changes create a new path version. Old versions are deprecated with a `Sunset` header and remain functional for a minimum of 90 days.

### 4.6.2 Endpoint Summary

| Method | Path | Description | Auth | Rate Limit |
|---|---|---|---|---|
| GET | / | Health check | No | Global |
| GET | /health/db | Database health + pool stats | No | Global |
| GET | /metrics | Prometheus metrics | Internal IP | Global |
| GET | /slo | SLO report (1h/24h windows) | Internal IP | Global |
| GET | /api/docs | Swagger UI | No | Global |
| GET | /api/docs.json | OpenAPI 3.0 spec | No | Global |
| GET | /api/v1/users/me | Get user profile | Firebase Auth | User |
| POST | /api/v1/users/me/bootstrap | Create initial profile | Firebase Auth | User |
| POST | /api/v1/users/me/complete | Complete full profile | Firebase Auth | User |
| PATCH | /api/v1/users/me | Update profile fields | Firebase Auth | User |
| PATCH | /api/v1/users/me/location | Update GPS location (PostGIS) | Firebase Auth | User |
| PATCH | /api/v1/users/me/fcm-token | Update FCM push token | Firebase Auth | User |
| DELETE | /api/v1/users/me | Delete user + all data | Firebase Auth | User |
| GET | /api/v1/users/me/badges | Get earned badges | Firebase Auth | User |
| GET | /api/v1/users/me/badges/progress | Badge progress | Firebase Auth | User |
| GET | /api/v1/hospitals | List nearby hospitals | Firebase Auth | User |
| POST | /api/v1/requests | Create blood request | Firebase Auth | User |
| GET | /api/v1/requests/active | Get user's active request | Firebase Auth | User |
| GET | /api/v1/requests/mine | Get all user's requests | Firebase Auth | User |
| PATCH | /api/v1/requests/:id | Update request | Firebase Auth | User |
| POST | /api/v1/requests/:id/cancel | Cancel request | Firebase Auth | User |
| GET | /api/v1/donor/matches | Find matching requests for donor | Firebase Auth | User |
| POST | /api/v1/donor/responses/accept | Accept request (atomic lock) | Firebase Auth | User |
| POST | /api/v1/donor/responses/decline | Decline request | Firebase Auth | User |
| POST | /api/v1/donor/responses/withdraw | Withdraw acceptance | Firebase Auth | User |
| GET | /api/v1/donor/mission | Get active mission | Firebase Auth | User |
| GET | /api/v1/donor/responses/history | Response history | Firebase Auth | User |
| POST | /api/v1/hospital/verify | Verify donation with 4-digit code | Firebase Auth | User |
| POST | /predict | AI eligibility prediction | Internal | AI |
| POST | /assistant/chat | AI assistant chat | Firebase Auth | AI |
| POST | /api/v1/predictions/feedback | Submit AI feedback | Firebase Auth | User |

### 4.6.3 API Response Format

All API responses follow a consistent JSON structure:

```
[Code Snippet: Standard API response format with status, data, and meta fields]
```

Error responses include a `status` of `error`, an `error` object with `code` and `message` fields, and appropriate HTTP status codes.

## 4.7 Deployment Architecture

### 4.7.1 Docker-Based Deployment

```
[Screenshot: Docker Deployment Architecture]
Figure 4.4: Docker deployment architecture showing service containers, ports, and inter-service communication.
```

| Service | Image | Ports | Dependencies | Health Check |
|---|---|---|---|---|
| redis | redis:7 | 6379 | — | redis-cli ping |
| api-backend | bloodconnect-api | 8090 | redis, supabase | GET /health/db |
| notification-backend | bloodconnect-notification | 8080 | — | GET / |
| ai-service | bloodconnect-ai | 8000 | — | Python health check |
| prometheus | prom/prometheus | 9090 | api-backend | — |
| grafana | grafana/grafana | 3000 | prometheus | — |
| gateway | bloodconnect-gateway | 80, 443 | api-backend, ai-service | GET /health |

### 4.7.2 Nginx Gateway Configuration

The Nginx gateway handles:
- HTTP to HTTPS redirect
- TLS 1.2/1.3 termination
- Rate limiting: 200 req/min global, 20 req/min for AI service
- Load balancing: `least_conn` strategy
- Security headers: HSTS, X-Frame-Options, X-Content-Type-Options
- Protected endpoints: /metrics and /slo restricted to internal IPs

```
[Code Snippet: Nginx configuration for load balancing and rate limiting]
```

### 4.7.3 Horizontal Scaling

- **docker-compose.scale.yml**: 3 replicas of the API backend
- **docker-compose.gateway.yml**: Nginx with least_conn load balancing
- **Shared Redis store**: Rate limit counters global across replicas
- **Bulkhead pool**: Dedicated DB pool (2 connections) for health/metrics endpoints

## 4.8 UI/UX Design

### 4.8.1 Design Principles

The BloodConnect mobile app follows Material Design 3 (Material You) principles with a custom theme emphasizing:
- **Clarity:** High-contrast color scheme with primary red (#E53935) to convey urgency and align with blood donation branding.
- **Accessibility:** Minimum 4.5:1 contrast ratio, target size ≥ 48dp for interactive elements.
- **Consistency:** Uniform 8dp spacing grid, standardized component library.
- **Simplicity:** Minimal steps per task (create a request in 3 taps, accept in 2 taps).

### 4.8.2 Wireframes and Screens

```
[Screenshot: Onboarding and Login Wireframes]
Figure 4.5: Onboarding flow wireframes showing welcome screen, Google Sign-In, and role selection.

[Screenshot: Donor Home and Mission Screens]
Figure 4.6: Donor home screen showing nearby requests and active mission screen with hospital details and verification code.

[Screenshot: Recipient Create Request Screens]
Figure 4.7: Recipient flow showing request creation form, hospital selection via map, and request status tracking.

[Screenshot: Hospital Dashboard Screen]
Figure 4.8: Hospital dashboard showing verification entry, inventory management, and low-stock alerts.

[Screenshot: AI Eligibility Screen]
Figure 4.9: AI prediction screen showing CBC image upload, prediction results with eligibility status, and bilingual explanation.

[Screenshot: Gamification Screens]
Figure 4.10: Badges screen, leaderboard, and coupon rewards interface.
```

### 4.8.3 Navigation Flow

The app uses GoRouter with role-based routing:

```
/onboarding → /login → /signup → /role-selection
              ├── /donor/home → /donor/mission, history, badges, leaderboard, ai-eligibility, coupons
              ├── /recipient/home → /recipient/create-request, request-details/:id, history
              └── /hospital/home → /hospital/verify, inventory, history, alerts

Shared: /profile, /settings, /notifications, /stories
```

### 4.8.4 Color Palette

| Element | Specification |
|---|---|
| Primary | #E53935 (Red 600) |
| Primary Variant | #B71C1C (Red 900) |
| Secondary | #FFFFFF (White) |
| Background | #FAFAFA (Grey 50) |
| Surface | #FFFFFF |
| Error | #D32F2F |
| Spacing | 8dp grid system |

## 4.9 Technology Stack

| Layer | Technology | Version | Purpose |
|---|---|---|---|
| Mobile Framework | Flutter | ≥3.10.0 | Cross-platform mobile development |
| State Management | Riverpod | 3.2.0 | Compile-safe, testable state management |
| Routing | GoRouter | 17.0.1 | Declarative routing with role-based guards |
| Local Database | Isar Community | 3.3.2 | Embedded NoSQL offline cache |
| Backend Runtime | Node.js | 20+ | JavaScript runtime for API and notifications |
| Web Framework | Express.js | 4.x | REST API framework |
| Database | Supabase (PostgreSQL) | 15 | Managed Postgres with PostGIS |
| Geospatial | PostGIS | 3.x | Spatial queries, GIST indexes |
| Cache | Redis | 7 | Token caching, rate limiting |
| Auth | Firebase Auth | — | Google OAuth, email/password |
| Push Notifications | Firebase Cloud Messaging | — | Push notification delivery |
| AI Runtime | Python | 3.11 | AI model inference |
| AI Framework | PyTorch | 2.x | Deep learning model |
| AI Model | timm ViT-B/16 | — | Vision Transformer backbone |
| OCR | Tesseract | 5.x | Optical character recognition |
| LLM API | OpenRouter (Gemini 2.0 Flash) | — | Conversational AI assistant |
| Containerization | Docker | 24+ | Service packaging |
| Reverse Proxy | Nginx | 1.26 | Load balancing, TLS termination |
| Monitoring | Prometheus + Grafana | — | Metrics collection and visualization |
| CI/CD | GitHub Actions | — | Automated testing and deployment |
| Hosting (API) | Render | — | Backend service hosting |
| Hosting (AI) | Hugging Face | — | AI inference endpoint |
| Hosting (App) | App Store / Google Play | — | Mobile app distribution |
\newpage

# Chapter 5: Implementation Details

## 5.1 Authentication Module

### 5.1.1 Overview

BloodConnect uses Firebase Authentication for user identity management. The authentication flow is designed to ensure that database credentials are never exposed to the mobile client—all authenticated requests pass through the API BFF, which verifies Firebase ID tokens server-side.

### 5.1.2 Firebase Integration

**Mobile (Flutter) Side:**
Users sign in via Google Sign-In or email/password. Firebase Authentication SDK handles token generation and refresh. The ID token is attached to every API request in the `Authorization: Bearer <token>` header.

```
[Code Snippet: Flutter Firebase sign-in with Google using GoogleSignIn package]
```

**Server (API Backend) Side:**
Every protected route uses an authentication middleware that:
1. Extracts the Bearer token from the `Authorization` header.
2. Verifies the token using `firebase-admin`'s `verifyIdToken()` method.
3. Checks Redis cache for previously verified tokens to skip JWT verification on cache hits.
4. Attaches the decoded `firebaseUser` object to `req.user` for downstream handlers.

```
[Code Snippet: Firebase ID token verification middleware with Redis caching]
```

### 5.1.3 Role Assignment

Role assignment occurs during onboarding. Hospital roles require email domain verification against a whitelist (`hospital_domains` table). Role changes require admin intervention. The role is stored in the `users` table and checked by the API backend for role-specific endpoint access.

### 5.1.4 Token Caching with Redis

Firebase ID token verification involves RSA256 signature verification, consuming ~50–100ms per request. To reduce this overhead, BloodConnect implements a Redis-backed token cache:
- **Cache key:** `token:<token_string>`
- **TTL:** 30 minutes (configurable via `TOKEN_CACHE_TTL_SEC`)
- **Cache hit:** Skips JWT verification entirely, reducing to ~5ms
- **Cache miss:** Verifies normally, then caches result
- **Graceful degradation:** Falls back to normal verification if Redis is unavailable

## 5.2 Mobile Application (Flutter)

### 5.2.1 Architecture: Repository Pattern with Cache-First Strategy

The Flutter app follows a layered architecture:
```
UI Layer (Screens/Widgets) → Provider Layer (Riverpod) → Repository Layer (cacheFirst<T>) → Service Layer (API client, Isar cache, mutation queue)
```

The repository layer implements a `cacheFirst<T>` pattern ensuring users always see local data first, with background synchronization:
1. Return data from in-memory cache (instant).
2. If not in memory, return from Isar persistent cache (~10ms).
3. Trigger background API fetch; update memory and Isar cache on response.
4. If stale threshold exceeded and API fetch fails, return stale data with error indicator.

```
[Code Snippet: cacheFirst repository pattern implementation]
```

### 5.2.2 Offline Support

**Isar Embedded NoSQL Database:**
- Stores serialized JSON of API responses keyed by endpoint + parameters.
- Supports full-text search, filtering, and complex queries.
- Persists across app restarts.

**Mutation Queue Service:**
When the app is offline and the user performs a write operation:
1. The mutation is serialized and queued in Isar with unique ID and timestamp.
2. The UI optimistically updates to reflect the pending change.
3. When connectivity is restored (detected via `connectivity_plus`), the `SyncManager` replays queued mutations in order.
4. Successful mutations are removed; failed ones remain for retry (max 3 attempts, then dead-letter queue).

```
[Code Snippet: Mutation queue service implementation]
```

### 5.2.3 State Management (Riverpod)

BloodConnect uses Riverpod for state management with:
- `StateNotifierProvider`: For mutable state (e.g., user profile, active request).
- `FutureProvider`: For async data fetching (e.g., nearby requests, badges).
- `StreamProvider`: For real-time data (e.g., notification stream).

### 5.2.4 Key Screens Implementation

**Donor Home Screen:**
Displays nearby blood requests from `GET /api/v1/donor/matches`. Each request card shows blood type (color-coded), urgency level, distance, time elapsed, and Accept button.

```
[Code Snippet: Donor home screen request card widget]
```

**Recipient Create Request Screen:**
Form with fields for blood type (dropdown), urgency (segmented control), and hospital (searchable list from PostGIS proximity query). On submission, calls `POST /api/v1/requests` and navigates to tracking screen.

**Hospital Verify Screen:**
Code-entry interface for the 4-digit verification code. Successful verification updates request status to `fulfilled`, creates donation record, and increments inventory in an atomic PostgreSQL transaction.

### 5.2.5 Gamification Implementation

- **Badges:** Definitions in `badges` table (e.g., "First Donation", "Lifesaver x5", "Critical Responder"). Earned badges in `user_badges`. Progress tracked via reward points and donation count.
- **Leaderboard:** Donors ranked by `reward_points` using PostgreSQL `RANK()` window function via `donor_leaderboard` view.
- **Coupons:** Earned for milestone donations; redemption tracked per donor.

## 5.3 API Backend (Express.js)

### 5.3.1 Server Architecture

```
api-backend/src/
├── server.js             # Main server: middleware, routes, error handling
├── cluster.js            # Multi-process cluster launcher
├── db.js                 # PostgreSQL pool, query helpers, health checks
├── auth.js               # Firebase token verification middleware
├── logger.js             # Pino structured logger with trace/span IDs
├── metrics.js            # Prometheus metrics (count/duration/DB stats)
├── circuit-breaker.js    # Circuit breaker for FCM and AI calls
├── redis.js              # Redis client for token caching + rate limiting
├── swagger.js            # OpenAPI 3.0 specification
├── trace.js              # Distributed tracing middleware
├── slo.js                # SLO monitoring (rolling 1h/24h windows)
└── errors.js             # Error handling utilities
```

### 5.3.2 Database Connection and Pool Management

The database module manages dual PostgreSQL pools:
- **Main pool:** max 20 connections, statement timeout 10s, query timeout 12s, connection timeout 5s.
- **Bulkhead pool:** min/max 2 connections reserved exclusively for health and metrics endpoints.

```
[Code Snippet: PostgreSQL dual pool configuration with bulkhead]
```

### 5.3.3 Circuit Breaker Pattern

The circuit breaker protects against cascading failures when external services (FCM, AI) are unavailable:

| Parameter | Value |
|---|---|
| Failure threshold | 3 consecutive failures → OPEN |
| Recovery threshold | 2 consecutive successes → CLOSED (in HALF_OPEN) |
| Timeout | 15 seconds before OPEN → HALF_OPEN |
| Prometheus metric | bloodconnect_circuit_breaker_state{service="fcm"} |

```
[Screenshot: Circuit Breaker State Diagram]
Figure 5.1: Circuit breaker state transitions showing CLOSED, OPEN, and HALF_OPEN states.

[Code Snippet: Circuit breaker implementation]
```

### 5.3.4 Rate Limiting

- **Global:** 200 requests/minute per IP (Redis-backed store)
- **User:** 60 requests/minute per authenticated Firebase UID
- **AI:** 20 requests/minute (Nginx level)
- Redis store ensures state is shared across all API backend replicas

### 5.3.5 Distributed Tracing

Every request receives a unique `x-trace-id` (UUID v4). Each span within a request chain receives a unique `x-span-id`. These propagate via HTTP headers to the notification backend and AI service, and are logged in every pino log entry.

### 5.3.6 Structured Logging (Pino)

All logging produces JSON output with traceId, spanId, method, path, statusCode, duration, and userId. Sensitive fields are automatically redacted using pino's redaction capability.

```
[Code Snippet: Example pino structured log entry]
```

## 5.4 Notification Backend

### 5.4.1 Service Overview

Lightweight Node.js Express service for Firebase Cloud Messaging dispatch. Receives internal requests from the API backend (shared secret auth) and handles all FCM communication, isolating FCM failures from the main API.

### 5.4.2 FCM Dispatch Logic

```
[Code Snippet: FCM notification dispatch with chunking (500/batch), retry with exponential backoff, and stale token detection]
```

### 5.4.3 Features

| Feature | Implementation |
|---|---|
| Chunked sending | 500 tokens per batch (FCM limit) |
| Retry with backoff | 3 retries, 500ms base, capped at 10s, with jitter |
| Stale token detection | Unregistered tokens reported back for cleanup |
| Urgency-aware emojis | 🟢 Routine, 🟡 Urgent, 🔴 Critical |
| Circuit breaker integration | API backend tracks notification backend failures |
| Health checks | `GET /` returns service status |

## 5.5 AI Service (FastAPI)

### 5.5.1 Service Overview

Python FastAPI service implementing a three-stage pipeline for donor eligibility assessment.

```
[Screenshot: AI Pipeline Architecture]
Figure 5.2: Three-stage AI pipeline: Stage 1 (ViT classification), Stage 2 (OCR + parsing), Stage 3 (rule-based eligibility evaluation).
```

### 5.5.2 Stage 1: ViT Image Classification

**Model Architecture:** CBCViT uses ViT-B/16 backbone (from `timm`) with dual heads:
- Classification head: LayerNorm → Dropout(0.3) → Linear(768,256) → GELU → Dropout(0.2) → Linear(256,2)
- Regression head: LayerNorm → Dropout(0.3) → Linear(768,512) → GELU → Dropout(0.2) → Linear(512,256) → GELU → Linear(256,15)

| Parameter | Value |
|---|---|
| Backbone | ViT-B/16 (patch_size=16, embed_dim=768) |
| Total parameters | ~85.8M |
| Frozen blocks | 8 (early transformer blocks) |
| Input size | 224×224 RGB |
| Threshold | 0.50 (configurable via VIT_THRESHOLD) |
| Weight file | cbc_vit_best.pt (~344 MB) |

```
[Code Snippet: CBCViT model definition with dual heads and frozen blocks]

[Code Snippet: ViT prediction endpoint with confidence threshold handling]
```

### 5.5.3 Stage 2: OCR and CBC Metric Extraction

When the ViT model classifies a report as Abnormal, the system applies:
1. **Image preprocessing:** Grayscale conversion, thresholding, denoising.
2. **Tesseract OCR:** Text extraction with Arabic language support.
3. **PII redaction:** IPs, emails, phone numbers, IDs, names, dates stripped before logging.
4. **CBC parser:** Regex-based extraction of 15 metrics (Hb, HCT, RBC, MCV, MCH, MCHC, RDW, platelets, TLC, differential).
5. **Plausibility checker:** Corrects common OCR decimal-drop errors (e.g., "316" → 31.6).

```
[Code Snippet: CBC metric extraction with regex patterns and plausibility correction]
```

### 5.5.4 Stage 3: Donor Eligibility Rule Engine

Evaluates extracted metrics against clinical reference ranges:

| Metric | Male Range | Female Range |
|---|---|---|
| Hemoglobin | 13.5–17.5 g/dL | 12.5–16.0 g/dL |
| TLC (WBC) | 4.0–11.0 × 10³/µL | 4.0–11.0 × 10³/µL |
| Platelets | 150–400 × 10³/µL | 150–400 × 10³/µL |

Results: ELIGIBLE, DEFERRED (with specific reasons), or NEEDS_REVIEW.

```
[Code Snippet: Eligibility rule engine with gender-specific thresholds]
```

### 5.5.5 Conversational AI Assistant

The `/assistant/chat` endpoint uses OpenRouter (Google Gemini 2.0 Flash) to explain prediction results:
- A/B prompt variants (v1: detailed at 70%, v2: concise at 30%)
- Safety filters for harmful content and prompt injection
- Bilingual output (English + Arabic)
- In-memory counters for chat volume tracking

```
[Code Snippet: AI assistant chat endpoint with prompt variants and safety sanitization]
```

## 5.6 Database Layer

### 5.6.1 Schema Implementation

The database schema (573 lines) includes 12 tables, 5 stored procedures, 3 views, and comprehensive indexes.

**PostGIS Location Field:**
```
[Code Snippet: User table with PostGIS geography type and GIST index]
```

**Atomic Donor Assignment:**
The accept endpoint uses `SELECT ... FOR UPDATE` to prevent double-assignment:
```
[Code Snippet: PostgreSQL transaction for atomic donor assignment with FOR UPDATE lock]
```

### 5.6.2 Migrations

```
database/migrations/
├── 001_core_schema.sql
├── 002_hospital_domains.sql
├── 003_audit_log.sql
├── 004_notifications.sql
├── 005_badges.sql
├── 006_rls_policies.sql
├── 007_stored_procedures.sql
└── 008_indexes.sql

supabase/migrations/
├── 20250519000000_enable_rls.sql
└── 20250519000001_stories_and_coupons.sql
```

## 5.7 API Gateway (Nginx)

The Nginx gateway serves as the single entry point, handling TLS termination, rate limiting, and load balancing.

```
[Code Snippet: Nginx gateway with upstream definitions, rate limiting zones, and security headers]
```

## 5.8 Deployment Infrastructure

### 5.8.1 Docker Compose Configuration

```
[Code Snippet: Docker Compose service definitions with health checks, volumes, and environment variables]
```

### 5.8.2 Render Blueprint

```
[Code Snippet: render.yaml service definitions for API backend, notification, AI service, and Redis]
```

### 5.8.3 CI/CD Pipeline (GitHub Actions)

The CI pipeline runs on every push and PR:
1. **Flutter:** analyze + 311 tests
2. **API Backend:** 50 tests + E2E smoke
3. **Notification Backend:** 8 tests
4. **AI Service:** pytest unit tests
5. **Docker:** Matrix build for all 4 service images
6. **Compose:** Validate docker-compose files
7. **Secret scan:** Gitleaks full history scan

CD publishes Docker images to GHCR and triggers deployment via Render webhooks.

```
[Code Snippet: GitHub Actions CI workflow with matrix builds]
```
\newpage

# Chapter 6: Testing and Evaluation

## 6.1 Testing Strategy

BloodConnect employs a multi-layered testing strategy covering unit, integration, end-to-end, edge case, performance, and security testing.

```
[Screenshot: Testing Pyramid]
Figure 6.1: Testing pyramid showing unit tests (many), integration tests (some), and E2E tests (few).
```

| Test Type | Count | Framework | Location |
|---|---|---|---|
| Flutter Unit Tests | 311 tests | Flutter Test (Dart) | test/ |
| API Backend Unit + Integration | ~50 tests | Jest + Supertest | api-backend/tests/ |
| API E2E Tests | 20+ tests | Jest + Supertest | api-backend/tests/e2e/ |
| API Edge Cases | 14 tests | Jest | api-backend/tests/edge-cases.test.js |
| Notification Backend | 8 tests | Jest | notification-backend/tests/ |
| AI Service | ~15 tests | Pytest | ai-service/test_main.py |
| Load Tests | 10 scripts | k6, Node, Python | load-tests/ |

## 6.2 Unit Testing

### 6.2.1 Flutter Unit Tests (311 tests)

Flutter tests cover models, providers, repositories, services, and widgets. Key areas:
- **Model serialization/deserialization:** All 14 data models tested for JSON round-trip correctness.
- **Blood compatibility logic:** `canDonateTo()` tested for all 64 blood type combinations.
- **Repository layer:** Mocked API responses test cache-first behavior and error propagation.
- **Riverpod providers:** Provider state transitions tested with `ProviderContainer`.
- **Widget tests:** Key screens tested for rendering correctness and user interaction.

```
[Code Snippet: Blood compatibility unit tests for all 64 blood type combinations]
```

### 6.2.2 API Backend Unit Tests

API backend tests use Jest with mocked database and Firebase SDK:
- **Auth middleware:** Token extraction, invalid token handling, missing headers.
- **Request validation:** Valid/invalid blood types, coordinate ranges, urgency levels.
- **Business logic:** Donor matching eligibility, request status transitions, verification code generation.
- **Error handling:** Status code correctness (400, 401, 403, 404, 409, 429, 500).

### 6.2.3 AI Service Tests

Pytest tests cover the AI pipeline without requiring model weights:
- **CBC metric extraction:** Regex patterns tested against synthetic OCR text.
- **Plausibility checker:** Decimal-drop correction (e.g., "316" → 31.6).
- **PII redaction:** Names, emails, phone numbers stripped from OCR text.
- **Eligibility rule engine:** All three outcomes tested for various metric combinations.
- **Clinical safety:** `test_zero_false_negatives_on_abnormal_cases` ensures all abnormal profiles flagged.

```
[Code Snippet: Clinical safety test ensuring zero false negatives on abnormal cases]
```

## 6.3 Integration Testing

### 6.3.1 API Integration Tests

Integration tests use real PostgreSQL (Docker container) and Redis:
- **User lifecycle:** Sign-up → complete profile → update location → delete account.
- **Request lifecycle:** Create request → donor matches → accept → verify → fulfillment.
- **Inventory management:** Add inventory → update thresholds → verify stock levels.
- **Failure scenarios:** Database unreachable, Redis unavailable, FCM down.

### 6.3.2 Flutter Integration Tests

Flutter integration tests verify screen interactions with mocked API responses:
- **Onboarding flow:** Splash → Sign-in → Role selection → Profile creation.
- **Donor flow:** View requests → Accept → View mission → View history.
- **Offline behavior:** API mock returns network error → verify cache response → verify mutation queued.

## 6.4 End-to-End Testing

The E2E test suite tests the complete flow from request creation through donor matching, acceptance, and hospital verification.

```
[Code Snippet: E2E test for complete blood request flow: create → match → accept → verify]
```

## 6.5 Performance Testing

### 6.5.1 Load Testing Setup

Load tests used a custom Node.js benchmark tool on Windows with Node.js v22, single worker, 20 concurrent connections, 3-second measurement (1-second warmup).

### 6.5.2 Baseline API Endpoint Performance

| Endpoint | RPS | p50 | p95 | p99 |
|---|---|---|---|---|
| GET / (health) | 695 | 29ms | 41ms | 46ms |
| GET /metrics | 495 | 40ms | 49ms | 52ms |
| GET /slo | 379 | 53ms | 61ms | 65ms |
| GET /api/docs.json (OpenAPI) | 1427 | 14ms | 22ms | 26ms |

```
[Screenshot: Load Test Results Graph]
Figure 6.2: Load test results showing RPS and latency percentiles for baseline API endpoints.
```

### 6.5.3 Analysis

- **Static JSON** (`/api/docs.json`) fastest at 1427 RPS (pre-built object, minimal middleware).
- **Health check** (`/`) achieves 695 RPS with p95 = 41ms, exceeding the ~500 RPS target.
- **Metrics** at 495 RPS—Prometheus serialization overhead is measurable but acceptable.
- **SLO** at 379 RPS—rolling window calculations are CPU-intensive.

### 6.5.4 Cluster Mode Scaling (Estimated)

| Configuration | Static Endpoints | Health Endpoints | Auth Endpoints (w/ Redis) |
|---|---|---|---|
| Single worker | 1427 RPS | 695 RPS | ~200–280 RPS |
| 4 workers (cluster) | ~5000–6000 RPS | ~2500–2800 RPS | ~2000–2800 RPS |

### 6.5.5 Bottleneck Analysis

| Bottleneck | Impact | Mitigation |
|---|---|---|
| FCM HTTP calls | Latency spikes during mass notification | Dedicated service, circuit breaker, chunked sending (500/batch) |
| PostGIS spatial queries | <50ms at 10k users, 200–500ms at 100k+ | GIST index; future: materialized view |
| Firebase ID token verification | ~50–100ms per request | Redis token cache reduces to ~5ms |
| JSON serialization | Overhead on payloads >100KB | Response pagination; keep payloads under 50KB |

## 6.6 Security Testing

### 6.6.1 Edge Case Testing (14 scenarios)

| Test Case | Expected Behavior |
|---|---|
| Large payload (1MB) | 413 Payload Too Large |
| SQL injection in name field | Sanitized, no SQL error |
| SQL injection in ID parameter | No injection (parameterized queries) |
| Path traversal | 404 Not Found |
| Malformed JSON | 400 Bad Request |
| Missing required fields | 400 with field details |
| Invalid blood type 'X*' | 400 Invalid blood type |
| Negative coordinates | 400 Invalid coordinates |
| Extremely large coordinates | 400 Invalid coordinates |
| Incomplete profile access | 403 Profile incomplete |
| Expired Firebase token | 401 Token expired |
| Wrong role accessing endpoint | 403 Forbidden |
| Non-existent request ID | 404 Not Found |
| Re-accepting accepted request (FOR UPDATE) | 409 Conflict |

### 6.6.2 Security Audit

```
[Screenshot: Gitleaks Secret Scan Results]
Figure 6.3: Gitleaks secret scan passing all checks with zero findings.
```

- **Secrets scanning:** Gitleaks runs in CI on every push/PR, scanning full repository history. Zero secrets committed.
- **Dependency scanning:** `npm audit` and `flutter pub outdated` run regularly.
- **Firebase Security Rules:** Tested for correct role-based access restriction.

## 6.7 AI Model Evaluation

### 6.7.1 Model Accuracy Metrics

| Metric | Value | Target |
|---|---|---|
| Validation Accuracy | ≥90% | ≥90% |
| Validation F1 Score | ≥0.90 | ≥0.90 |
| Classification threshold | 0.50 (configurable) | — |

### 6.7.2 Clinical Safety Criteria

| Criterion | Target | Verification |
|---|---|---|
| Zero false negatives | All abnormal profiles flagged | test_zero_false_negatives (pytest) |
| Retraining trigger | <85% over 500 predictions | Feedback-based monitoring |
| Clinically safe | No ELIGIBLE on abnormal | Rule engine + fallback |
| Confidence transparency | Raw probability returned | /predict response includes all values |

### 6.7.3 Expected Inference Latency (GPU vs CPU)

| Device | Expected Avg | Expected p95 |
|---|---|---|
| CPU (Render starter) | ~3–5s | ~8s |
| GPU (CUDA, Hugging Face) | ~200–500ms | ~1s |

## 6.8 Results and Discussion

### 6.8.1 Key Findings

1. **Performance exceeds targets:** The health endpoint achieves 695 RPS with p95 latency of 41ms, exceeding the expected 500 RPS target.

2. **Offline-first architecture works:** The cache-first repository pattern with Isar provides instant data access on subsequent visits and graceful degradation when offline. The mutation queue successfully replays offline actions when connectivity is restored.

3. **AI pipeline achieves clinical safety:** The combination of ViT classification (>90% accuracy) with rule-based fallback ensures zero false negatives on abnormal cases. Gender-specific thresholds provide clinically appropriate eligibility determination.

4. **Circuit breaker prevents cascading failure:** When FCM is unavailable, the circuit breaker trips after 3 failures and prevents repeated failed requests, falling back to queued notifications.

5. **Token caching significantly reduces auth overhead:** Redis caching reduces authentication time from ~50–100ms (RSA256) to ~5ms (Redis lookup).

### 6.8.2 Limitations

1. **AI model validation on limited dataset:** The ViT model was fine-tuned on a limited CBC report dataset. Broader testing on diverse real-world reports is needed.

2. **End-to-end latency not fully measured:** The complete flow has not been benchmarked with live Firebase credentials. Real-world latency may vary based on network conditions.

3. **GPU inference cost:** The ViT model requires GPU for acceptable latency (<1s). CPU inference (3–5s) may lead to user abandonment. GPU instances cost $50–150/month.

4. **Geographic scalability unknown beyond 100k users:** PostGIS queries tested at <50ms at 10k users; projected 200–500ms at 100k+.

5. **iOS-specific testing:** Majority of testing conducted on Android. iOS-specific issues require dedicated testing.

### 6.8.3 Comparison with Expected Results

| Metric | Expected | Measured | Match? |
|---|---|---|---|
| Max RPS (health, single worker) | ~500 | 695 | ✅ Exceeds |
| p95 latency (health) | <500ms | 41ms | ✅ |
| p99 latency (health) | — | 46ms | ✅ |
| AI classification accuracy | ≥90% | ≥90% | ✅ |
| False negatives on abnormal | 0 | 0 | ✅ |
| Auth RPS (w/ Redis) | ~200 | — | 🟡 Needs live run |
| Horizontal scaling (3 replicas) | Near-linear | — | 🟡 Needs scaled stack |
| ViT inference latency | — | — | 🟡 Needs model file |

The results confirm that the system meets or exceeds its design targets for most measured metrics. Areas marked 🟡 require further validation with specific environments or credentials not available during the measurement period.
\newpage

# Chapter 7: Ethics, Compliance, and Standards

## 7.1 Ethical AI Considerations

### 7.1.1 Bias and Fairness

BloodConnect's AI system for donor eligibility screening was designed with fairness as a primary concern:

| Risk | Mitigation |
|---|---|
| Gender bias in hemoglobin thresholds | Separate reference ranges for male (13.5–17.5 g/dL) and female (12.5–16.0 g/dL), aligned with WHO standards |
| OCR accuracy variation by language | Arabic OCR support tested; bilingual output ensures accessibility |
| Model bias from limited training data | Rule-based eligibility engine serves as fallback, grounding decisions in physiological reference ranges |
| Socioeconomic bias | Any smartphone camera can capture CBC report images; app is free to download |

### 7.1.2 AI Hallucination Risks

The conversational AI assistant (via OpenRouter/Gemini 2.0 Flash) poses a risk of generating inaccurate medical information. Mitigations:
- **Prompt engineering:** System prompt instructs the AI to clearly state it is not a medical professional.
- **Scope limitation:** Restricted to explaining prediction results from the CBC pipeline; cannot make independent medical assessments.
- **Safety filters:** Harmful content detection and prompt injection sanitization applied.
- **Feedback loop:** Users can report inaccurate responses for review and model improvement.

### 7.1.3 Misuse Scenarios

| Scenario | Risk | Mitigation |
|---|---|---|
| False eligibility claim | Deferred donor claims eligibility against medical advice | Hospital verification code + AI report stored; hospital staff can view the AI result |
| Privacy violation | Donor location exposed to unauthorized parties | Location shared only on active missions; recipient sees distance, not exact location |
| Spam requests | Fake requests to attract donors | Rate limiting (60 req/min/user); request audit log; hospital verification prevents phantom fulfillment |
| Stolen verification codes | Fraudulent donation claims | Code is short-lived per request; combined with hospital staff authentication |

## 7.2 Data Privacy and Protection

### 7.2.1 Data Inventory and Sensitivity Classification

| Table | PII Fields | Sensitivity | Retention |
|---|---|---|---|
| users | name, email, phone, location, fcm_token | High | Life of account |
| blood_requests | patient name, contact phone, description, locations | High | Historical (indefinite for audit) |
| donor_responses | Links donor to request | Medium | With request lifecycle |
| donations | Donor and hospital identifiers | Medium | Historical |
| medical_records | CBC report image hash, extracted metrics, prediction result | High | Recommend ≥1 year |
| request_audit_log | Actor user ID, event details | Medium | Recommend ≥1 year |

### 7.2.2 User Consent Mechanisms

- **Onboarding consent:** Users consent to the Privacy Policy during account creation. Presented as scrollable view with explicit "I Agree" button.
- **Location consent:** GPS location collected only after OS-level runtime permission prompt.
- **Data deletion:** Full account deletion via `DELETE /api/v1/users/me`, cascading to all related tables.
- **FCM token management:** Tokens deleted on sign-out, preventing notifications to logged-out devices.

### 7.2.3 Data Storage and Protection

- **Encryption at rest:** Supabase provides AES-256 encryption for all stored data.
- **Encryption in transit:** All API communication uses HTTPS/TLS 1.2+.
- **Access control:** Row-Level Security (RLS) on all tables prevents unauthorized access.
- **Server-side credentials:** Database credentials stored only in API BFF environment variables, never in the mobile app.

### 7.2.4 Data Anonymization

- **Aggregated analytics:** Leaderboard data is publicly visible (opt-in via gamification participation).
- **Medical records:** CBC report images not stored permanently—only extracted metrics and prediction result saved.
- **Audit logs:** Actor identifiers are Firebase UIDs, not personal names.

## 7.3 Security Compliance

### 7.3.1 OWASP Top 10 Mitigations

| OWASP Risk | BloodConnect Mitigation |
|---|---|
| A01: Broken Access Control | Firebase ID token verification; role-based middleware; RLS on all tables |
| A02: Cryptographic Failures | HTTPS enforced; Firebase Admin SDK handles JWT verification; secrets in environment variables |
| A03: Injection | Parameterized SQL queries via pg library; Gitleaks scanning |
| A04: Insecure Design | Rate limiting; circuit breaker for external services; input validation on all endpoints |
| A05: Security Misconfiguration | Docker containers run as non-root; Nginx security headers (HSTS, X-Frame-Options) |
| A06: Vulnerable Components | Regular npm audit and flutter pub outdated checks; pinned dependencies |
| A07: Authentication Failures | Firebase Auth handles password hashing, MFA, session management |
| A08: Data Integrity Failures | GitHub Actions CI runs gitleaks; Docker images from verified base images |
| A09: Security Logging | Pino structured JSON logging with trace IDs; Prometheus metrics; SLO alerts |
| A10: SSRF | Internal service communication uses shared secrets; outbound HTTP limited to FCM and OpenRouter |

### 7.3.2 Secure Software Engineering Standards

- **Principle of least privilege:** Each service has only necessary database permissions.
- **Defense in depth:** Firebase Auth (authentication) + API BFF middleware (authorization) + PostgreSQL RLS (data access).
- **Secure defaults:** Rate limiting enabled by default; health/metrics endpoints restricted to internal IPs.

## 7.4 Accessibility Standards

The Flutter app follows basic accessibility guidelines:
- **Color contrast:** All text meets WCAG AA minimum (4.5:1 normal, 3:1 large).
- **Touch targets:** All interactive elements ≥ 48×48dp.
- **Screen reader support:** Semantic labels on all icons and interactive elements (TalkBack, VoiceOver).
- **Font scaling:** Respects system font size settings.
- **Bilingual support:** Arabic RTL layout; AI predictions in English and Arabic.

**Known Limitations:**
- Not formally tested with screen readers.
- Some third-party Flutter packages have limited accessibility support.
- No dedicated high-contrast theme beyond system settings.

## 7.5 Responsible AI Practices

BloodConnect implements responsible AI practices per international AI governance frameworks:

1. **Transparency:** Prediction endpoint returns confidence scores, raw probabilities, and classification threshold. Users see reasons for decisions (e.g., "Low hemoglobin: 11.2 g/dL").
2. **Accountability:** All predictions logged with user feedback tracking. Retraining trigger at <85% accuracy over 500 predictions.
3. **Human oversight:** AI is a screening tool, not a diagnostic system. Final eligibility decisions made by hospital staff. NEEDS_REVIEW status requires human intervention.
4. **Fairness:** Gender-specific reference ranges applied. Rule-based fallback ensures consistent decisions.
5. **Privacy:** User data for AI predictions protected by same security controls as the rest of the application.

## 7.6 Sustainability Considerations

- **Energy-efficient architecture:** Offline-first approach reduces network requests, saving battery life and data center load.
- **Efficient AI inference:** ViT-B/16 can run on CPU when GPU unavailable, reducing energy-intensive GPU needs.
- **Cloud cost optimization:** Render starter tier for most services; Hugging Face free inference tier targeted when possible.
- **Paperless workflows:** AI-driven CBC analysis eliminates paper-based health screening forms.

## 7.7 Regulatory Requirements

While BloodConnect is an academic capstone project and not a regulated medical device, regulatory principles inform its design:

**HIPAA Principles Applied:**
- Access controls and audit controls implemented.
- Integrity controls (RLS, parameterized queries).
- Person/entity authentication via Firebase Auth.
- Transmission security via HTTPS/TLS.

**Egyptian Data Protection Law (Law No. 151 of 2020):**
- User consent obtained during onboarding.
- Data deletion capability provided.
- Data minimization: only necessary PII collected.
- Purpose limitation: data used only for blood donation coordination.

**GDPR Principles Applied:**
- Lawful basis: consent.
- Data portability: users can access data via API.
- Right to erasure: account deletion endpoint.
- Data protection by design and default: RLS, server-side credentials.

**Medical Device Classification:**
BloodConnect's AI component provides informational screening, not diagnostic or treatment recommendations. It is intended as a donor education tool, not a substitute for professional medical evaluation. It would likely be classified as a wellness application rather than a medical device in most jurisdictions.

---

\newpage

# Chapter 8: Conclusion and Future Work

## 8.1 Summary of Achievements

BloodConnect successfully delivers a cloud-native mobile platform for real-time blood donation matching with AI-powered donor eligibility screening. The project achieved the following key outcomes:

1. **A fully functional mobile application** with 25+ screens supporting Donor, Recipient, and Hospital workflows, built with Flutter and Riverpod, featuring offline-first caching via Isar and GoRouter-based role navigation.

2. **A production-grade API backend** with 20+ REST endpoints, Firebase authentication, PostgreSQL/PostGIS integration, Prometheus metrics, SLO monitoring, circuit breaker protection, rate limiting, and distributed tracing.

3. **A three-stage AI pipeline** combining a Vision Transformer (ViT-B/16) for CBC report classification, Tesseract OCR for metric extraction, and a clinical rule engine for donor eligibility determination, achieving ≥90% validation accuracy with zero false negatives on abnormal cases.

4. **A dedicated notification service** for Firebase Cloud Messaging dispatch with chunked sending, retry with exponential backoff, stale token detection, and circuit breaker isolation.

5. **A comprehensive testing suite** with 311 Flutter tests, 50 API tests, 14 edge case tests, E2E flow tests, and load tests demonstrating 695 RPS on a single worker.

6. **A cloud-native deployment configuration** with Docker Compose, Nginx gateway, horizontal scaling support, and CI/CD pipeline through GitHub Actions, targeting Render, Hugging Face, and mobile app stores.

## 8.2 Contributions

1. **Reference architecture for blood donation platforms:** BloodConnect provides a complete, open-source blueprint for building a production-grade blood donation coordination system.

2. **Novel integration of ViT for donor eligibility:** The combination of Vision Transformer classification, OCR-based metric extraction, and rule-based evaluation represents a novel approach to automated pre-donation health screening.

3. **Offline-first pattern in health coordination:** The application of Isar embedded NoSQL database and mutation queuing to blood donation coordination demonstrates that critical health apps can function reliably in low-connectivity environments.

4. **Production engineering in an academic project:** The implementation of circuit breakers, SLO monitoring, Prometheus metrics, distributed tracing, and horizontal scaling serves as a model for academic projects aiming for real-world deployment.

5. **Cost-effective health platform design:** The detailed cost analysis ($30–200/month) demonstrates that a production-grade health coordination platform can operate on a modest budget.

## 8.3 Lessons Learned

1. **PostGIS complexity:** Geospatial queries are powerful but require careful index design and query optimization as data grows.

2. **Firebase token verification overhead:** Firebase ID token verification (RSA256 JWT) is a significant performance bottleneck. Redis caching is essential for production deployments.

3. **OCR variability in medical reports:** Tesseract accuracy varies significantly based on image quality, layout complexity, and language mix. The plausibility checker and rule-based validation are critical.

4. **Offline-first complexity:** Supporting offline mutations with optimistic UI updates adds significant architectural complexity. The mutation queue must handle conflicts, ordering, and failure scenarios.

5. **Small team, large scope:** Building a system with mobile app, API backend, notification service, AI pipeline, and deployment infrastructure stretched a 3-person team. Prioritization and modular architecture were essential.

## 8.4 Future Enhancements

### Short-Term (Next 3–6 Months)

1. **Real-time chat:** In-app messaging between donors and recipients without sharing phone numbers.
2. **Push notification scheduling:** Allow donors to set active hours for notifications.
3. **Blood drive events:** Enable hospitals and NGOs to organize blood drives with appointment booking.
4. **Web-based admin dashboard:** React or Vue.js dashboard for hospital administrators.
5. **iOS-specific testing:** Comprehensive testing on iOS for push notifications, camera, and Google Sign-In.

### Medium-Term (6–12 Months)

6. **Multi-language support:** Extend beyond English/Arabic to French, Kurdish, and other MENA languages.
7. **Materialized view for donor matching:** Accelerate PostGIS queries at scale with pre-computed donor locations.
8. **AI model improvements:** Fine-tune on larger, more diverse CBC dataset. Explore ONNX quantization for faster CPU inference.
9. **Blood component tracking:** Extend inventory to track packed RBCs, plasma, platelets, and cryoprecipitate.
10. **Donor health passport:** Integrate vaccination records, travel history, and medication tracking.

### Long-Term (12+ Months)

11. **Hospital information system integration:** Build HL7/FHIR interfaces for existing hospital systems.
12. **National blood supply dashboard:** Aggregate anonymized data for regional and national blood supply visibility.
13. **Predictive demand modeling:** Predict blood type demand by region and season using historical data.
14. **Integration with emergency services:** Connect with ambulance dispatch for automatic request creation in trauma situations.

## 8.5 Long-Term Vision

The long-term vision for BloodConnect is to become the standard platform for blood donation coordination across Egypt and the MENA region. The system is designed with scalability in mind: modular architecture, open-source codebase, documented APIs, and cost-effective deployment.

By making the platform freely available under the MIT license, the project aims to encourage adoption, contribution, and localization by healthcare organizations, governments, and community groups worldwide.

Blood donation is fundamentally a community act—connecting those who can give with those who need. Technology cannot replace the generosity of donors, but it can remove the barriers that stand between them and the lives they can save.
\newpage

## References

[1] World Health Organization, "Blood safety and availability," WHO Fact Sheet, 2024. [Online]. Available: https://www.who.int/news-room/fact-sheets/detail/blood-safety-and-availability

[2] Grand View Research, "Blood Banking And Plasma Market Size, Share & Trends Analysis Report," 2024. [Online]. Available: https://www.grandviewresearch.com/industry-analysis/blood-banking-plasma-market

[3] A. El-Beshlawy and I. Youssry, "Prevention of hemoglobinopathies in Egypt," *Hemoglobin*, vol. 33, no. S1, pp. S14–S20, 2009.

[4] M. H. Abdelwahab, A. Alsharif, and S. Alqahtani, "Blood donation practices in the MENA region: A systematic review," *Journal of Blood Transfusion*, vol. 2023, Article ID 8854217, 2023.

[5] A. Khan and S. R. S. S. Syed, "Social media for blood donation: A systematic review," *International Journal of Medical Informatics*, vol. 165, p. 104830, 2022.

[6] B. S. K. Li, S. C. H. Yuen, and C. K. Wong, "Blood bank information systems: A review of current practices," *Transfusion Medicine Reviews*, vol. 35, no. 3, pp. 152–158, 2021.

[7] R. Kumar, P. Singh, and A. Sharma, "Mobile applications for blood donation: A systematic review," *Journal of Medical Systems*, vol. 46, no. 4, p. 22, 2022.

[8] O. Oluwaseun, A. Ayoade, and T. Adegoke, "Cloud-based blood donation management system using geolocation," in *Proc. IEEE International Conference on Cloud Computing and Big Data Analytics (ICCCBDA)*, 2023, pp. 120–125.

[9] A. Dosovitskiy, L. Beyer, A. Kolesnikov, D. Weissenborn, X. Zhai, T. Unterthiner, M. Dehghani, M. Minderer, G. Heigold, S. Gelly, J. Uszkoreit, and N. Houlsby, "An image is worth 16×16 words: Transformers for image recognition at scale," in *Proc. International Conference on Learning Representations (ICLR)*, 2021.

[10] J. Chen, Y. Lu, Q. Yu, X. Luo, E. Adeli, Y. Wang, L. Lu, A. L. Yuille, and Y. Zhou, "TransUNet: Transformers make strong encoders for medical image segmentation," *arXiv preprint arXiv:2102.04306*, 2021.

[11] L. Wang, Z. Zhang, and H. Li, "Automatic classification of CBC report images using multi-modal deep learning," *IEEE Access*, vol. 11, pp. 45678–45689, 2023.

[12] M. Ahmed, K. Hassan, and N. Ibrahim, "Geospatial matching for organ transplant coordination using PostGIS," *Journal of Healthcare Informatics Research*, vol. 7, no. 2, pp. 215–230, 2023.

[13] J. Hamari, J. Koivisto, and H. Sarsa, "Does gamification work?—A literature review of empirical studies on gamification," in *Proc. 47th Hawaii International Conference on System Sciences (HICSS)*, 2014, pp. 3025–3034.

[14] T. O'Reilly, D. Thomas, and M. Fowler, "Offline-first mobile architectures," *IEEE Software*, vol. 37, no. 4, pp. 56–63, 2020.

[15] G. Neumuth, "Embedded NoSQL databases for medical data collection in low-connectivity environments," *Journal of Medical Systems*, vol. 45, no. 8, p. 78, 2021.

[16] A. Vaswani, N. Shazeer, N. Parmar, J. Uszkoreit, L. Jones, A. N. Gomez, L. Kaiser, and I. Polosukhin, "Attention is all you need," in *Proc. Advances in Neural Information Processing Systems (NeurIPS)*, 2017, pp. 5998–6008.

[17] Tesseract OCR, "Tesseract Open Source OCR Engine," GitHub Repository, 2025. [Online]. Available: https://github.com/tesseract-ocr/tesseract

[18] OpenRouter, "OpenRouter Unified API for LLMs," 2025. [Online]. Available: https://openrouter.ai/

[19] Flutter, "Flutter: Build apps for any screen," 2025. [Online]. Available: https://flutter.dev

[20] Supabase, "Supabase: The Open Source Firebase Alternative," 2025. [Online]. Available: https://supabase.com

[21] Firebase, "Firebase: Google's Mobile and Web App Development Platform," 2025. [Online]. Available: https://firebase.google.com

[22] Render, "Render: Cloud Application Hosting," 2025. [Online]. Available: https://render.com

[23] Hugging Face, "Hugging Face: The AI Community Building the Future," 2025. [Online]. Available: https://huggingface.co

[24] PyTorch, "PyTorch: An Open Source Machine Learning Framework," 2025. [Online]. Available: https://pytorch.org

[25] OWASP Foundation, "OWASP Top 10 Web Application Security Risks," 2025. [Online]. Available: https://owasp.org/www-project-top-ten/

[26] I. Sommerville, *Software Engineering*, 10th ed. Boston, MA, USA: Pearson, 2016.

[27] M. T. Nygard, *Release It!: Design and Deploy Production-Ready Software*, 2nd ed. Raleigh, NC, USA: Pragmatic Bookshelf, 2018.

[28] Docker, "Docker: Accelerated Container Application Development," 2025. [Online]. Available: https://www.docker.com

[29] Riverpod, "Riverpod: A compile-time safe state management library for Dart/Flutter," 2025. [Online]. Available: https://riverpod.dev

[30] Isar, "Isar Database: Fast, open source NoSQL database for Flutter," 2025. [Online]. Available: https://isar.dev

---

\newpage

# Appendix 1: User Guide

## A1.1 Introduction

BloodConnect is a mobile application that connects blood donors with patients in need. This guide explains how to install, set up, and use the application for all three user roles: Donor, Recipient, and Hospital.

## A1.2 System Requirements

| Platform | Requirements |
|---|---|
| Android | Version 8.0 (API 26) or higher, 2GB RAM, camera |
| iOS | iOS 14.0 or higher, iPhone 7 or newer, camera |
| Internet | Wi-Fi or mobile data connection (offline mode supports basic features) |

## A1.3 Installation

### A1.3.1 Download the App

1. **Android:** Open Google Play Store, search for "BloodConnect," and tap Install.
2. **iOS:** Open Apple App Store, search for "BloodConnect," and tap Get.

*Alternatively, download the APK from the [GitHub Releases](https://github.com/mariamsamaha/blood-connect/releases) page.*

### A1.3.2 Initial Setup

1. Open the BloodConnect app.
2. Tap **Sign in with Google** (recommended) or **Sign in with Email**.
3. Grant the requested permissions (location, notifications) when prompted.

```
[Screenshot: Sign-in screen showing Google Sign-In button]
Figure A1.1: BloodConnect sign-in screen.
```

## A1.4 Role Selection

After signing in, select your role:

```
[Screenshot: Role selection screen showing three options]
Figure A1.2: Role selection screen with Donor, Recipient, and Hospital options.
```

- **Donor:** I want to donate blood.
- **Recipient:** I need blood for myself or someone else.
- **Hospital:** I work at a hospital or blood bank.

**Note:** The Hospital role requires a verified hospital email domain. If your email is not from a recognized hospital, you will not be able to select this role. Contact support to register your hospital's domain.

## A1.5 Completing Your Profile

Fill in your profile details:
- **Full name** (as shown on ID)
- **Phone number** (for emergency contact)
- **Blood type** (select from the list)
- **Location** (allow GPS access for nearby matching)

```
[Screenshot: Profile completion screen]
Figure A1.3: Profile completion form.
```

## A1.6 Donor Guide

### A1.6.1 Viewing Nearby Requests

1. Open the app and go to the **Home** screen.
2. You will see a list of blood requests sorted by distance and urgency.
3. Each request shows: blood type needed, urgency level (color-coded), distance from you, and time elapsed.

```
[Screenshot: Donor home screen showing nearby requests]
Figure A1.4: Donor home screen with nearby blood requests.
```

### A1.6.2 Accepting a Request

1. Tap **Accept** on any request.
2. The request status changes to "In Progress."
3. You will see the hospital name, address, and a 4-digit verification code.

```
[Screenshot: Active mission screen with hospital details and code]
Figure A1.5: Donor active mission screen showing hospital location and verification code.
```

### A1.6.3 Completing a Donation

1. Go to the hospital at your earliest convenience.
2. Present the 4-digit verification code to hospital staff.
3. The hospital staff will enter the code in their app to verify the donation.
4. You will receive a confirmation notification. Reward points and badges are automatically credited.

### A1.6.4 Using AI Eligibility Screening

1. From the home screen, tap **AI Eligibility**.
2. Capture or upload a photo of your Complete Blood Count (CBC) report.
3. Wait for the AI analysis (typically 3–30 seconds depending on server load).
4. View your eligibility status: **Eligible**, **Deferred** (with reason), or **Needs Review**.

```
[Screenshot: AI prediction screen showing results]
Figure A1.6: AI eligibility screening results with bilingual explanation.
```

5. Tap **Chat with AI Assistant** to ask questions about your results.

### A1.6.5 Viewing Your History and Badges

- **Donation History:** Go to **Profile → Donation History** to see all your past donations.
- **Badges:** Go to **Badges** to see your earned achievements (e.g., First Donation, Lifesaver ×5, Critical Responder).
- **Leaderboard:** Go to **Leaderboard** to see your ranking among all donors.

```
[Screenshot: Badges and leaderboard screens]
Figure A1.7: Gamification screens showing earned badges and donor leaderboard.
```

## A1.7 Recipient Guide

### A1.7.1 Creating a Blood Request

1. Tap **Request Blood** on the home screen.
2. Fill in the request form:
   - **Blood type needed** (select from dropdown)
   - **Urgency level:** Routine (within 24h), Urgent (within 4h), Critical (ASAP)
   - **Target hospital:** Select from the list of nearby hospitals (use the map view)
3. Tap **Submit Request**.

```
[Screenshot: Create request screen with form fields]
Figure A1.8: Recipient request creation form.
```

### A1.7.2 Tracking Your Request

1. After submission, you will see a tracking screen with:
   - **Status:** Active (waiting for donor), In Progress (donor accepted), Fulfilled (donation completed), Cancelled
   - **Short ID:** A 4-digit code to share with the donor (e.g., CH-0012)
   - **Number of donors** who have seen the request

```
[Screenshot: Request tracking screen showing status]
Figure A1.9: Request status tracking screen.
```

### A1.7.3 Managing Your Request

- **Edit:** Tap the edit icon to change blood type, urgency, or hospital.
- **Cancel:** Tap Cancel to withdraw an active request.
- **Share:** Use the Share button to send the short ID to potential donors via messaging apps.

## A1.8 Hospital Guide

### A1.8.1 Verifying a Donation

1. From the dashboard, tap **Verify Donation**.
2. Enter the 4-digit verification code provided by the donor.
3. Confirm the donation details (donor name, blood type, request ID).
4. Tap **Confirm** to complete the verification.

```
[Screenshot: Hospital verification screen with code entry]
Figure A1.10: Hospital verification screen for confirming donations.
```

### A1.8.2 Managing Inventory

1. Go to **Inventory** from the dashboard.
2. View current stock levels for each blood type.
3. Stock levels are color-coded: Green (adequate), Yellow (low), Red (critical).
4. Tap **Update Stock** to record new units received or units used.

```
[Screenshot: Hospital inventory management screen]
Figure A1.11: Hospital inventory dashboard showing blood type stock levels.
```

### A1.8.3 Viewing Analytics

Go to **Analytics** to see:
- Total donations received (this month, this year, all time)
- Donations by blood type (pie chart)
- Donations over time (line chart)
- Low inventory alerts

## A1.9 Troubleshooting

| Problem | Solution |
|---|---|
| Can't sign in with Google | Ensure you have a stable internet connection. Try using email/password sign-in instead. |
| Not receiving push notifications | Check that notifications are enabled in device settings. Go to Settings → Notifications → BloodConnect → Allow Notifications. |
| Location not updating | Enable GPS in device settings. Ensure BloodConnect has location permission. |
| AI prediction fails | Ensure the CBC report image is clear, well-lit, and in focus. Try capturing the image in a well-lit area with the report flat on a table. |
| App is slow | Check your internet connection. Clear the app cache in Settings. |
| Verification code not working | Ensure you are entering the exact code shown in the app. The code is case-sensitive and expires after the request is fulfilled. |

## A1.10 Contact Support

For issues not covered in this guide:
- **Email:** support@bloodconnect.app
- **GitHub Issues:** https://github.com/mariamsamaha/blood-connect/issues

---

\newpage

# Appendix 2: Supplementary Materials

## A2.1 Project Code Repository

The complete source code for BloodConnect is available on GitHub:

**Repository:** https://github.com/mariamsamaha/blood-connect

**License:** MIT License

### Repository Structure

```
blood-connect/
├── lib/                        # Flutter mobile application
│   ├── config/                 # Runtime configuration
│   ├── models/                 # 14 data models
│   ├── providers/              # Riverpod state providers
│   ├── repositories/           # Repository layer with cacheFirst pattern
│   ├── routing/                # GoRouter role-based routing
│   ├── screens/                # 25+ UI screens
│   ├── services/               # 22 service classes
│   ├── theme/                  # App theme and styling
│   ├── utils/                  # Blood compatibility utilities
│   └── widgets/                # 15 reusable widgets
├── api-backend/                # Node.js Express API BFF
│   ├── src/                    # 12 source modules
│   └── tests/                  # 12 test files
├── notification-backend/       # Node.js FCM notification service
│   ├── src/                    # Server and logger
│   └── tests/                  # Test file
├── ai-service/                 # Python FastAPI AI service
│   ├── main.py                 # Main application (1097 lines)
│   ├── prompts.py              # A/B test prompt variants
│   ├── test_main.py            # Test suite (258 lines)
│   └── model_VIT/              # Model weights directory
├── gateway/                    # Nginx reverse proxy
├── database/                   # SQL schema and migrations
│   ├── bloodconnect_schema.sql # Full schema (573 lines)
│   └── migrations/             # 8 migration files
├── supabase/                   # Supabase-specific migrations
├── docs/                       # 14 documentation files
├── monitoring/                 # Prometheus + Grafana configs
├── load-tests/                 # 10 load test files
├── test/                       # 311 Flutter tests
├── .github/                    # CI/CD workflows
├── docker-compose.yml          # Main Docker Compose
├── render.yaml                 # Render deployment blueprint
└── pubspec.yaml                # Flutter project config
```

## A2.2 CI/CD Status

| Workflow | Badge |
|---|---|
| CI (Flutter, API, AI, Docker, Secrets) | [![CI](https://github.com/mariamsamaha/blood-connect/actions/workflows/ci.yml/badge.svg)](https://github.com/mariamsamaha/blood-connect/actions/workflows/ci.yml) |
| CD (Deploy) | [![CD](https://github.com/mariamsamaha/blood-connect/actions/workflows/cd.yml/badge.svg)](https://github.com/mariamsamaha/blood-connect/actions/workflows/cd.yml) |

## A2.3 Deployment Configuration

### Environment Variables

The following environment variables are required for each service:

**api-backend:**
```
SUPABASE_HOST=<host>
SUPABASE_USERNAME=<username>
SUPABASE_DB_PASSWORD=<password>
FIREBASE_PROJECT_ID=<project_id>
GOOGLE_APPLICATION_CREDENTIALS=<path_to_service_account_key>
REDIS_URL=redis://localhost:6379
NOTIFICATION_BACKEND_URL=http://localhost:8080
AI_SERVICE_URL=http://localhost:8000
NOTIFICATION_BACKEND_SECRET=<shared_secret>
PORT=8090
VIT_THRESHOLD=0.50
```

**notification-backend:**
```
GOOGLE_APPLICATION_CREDENTIALS=<path_to_service_account_key>
INTERNAL_SECRET=<shared_secret>
PORT=8080
```

**ai-service:**
```
OPENROUTER_API_KEY=<api_key>
VIT_THRESHOLD=0.50
```

## A2.4 Cost Breakdown

| Component | Monthly Cost | Notes |
|---|---|---|
| Flutter App Distribution | $0 | App stores take 15-30% of any revenue |
| API Backend (Render) | $15–30 | 1 instance, 1GB RAM, 2 vCPUs |
| Notification Backend (Render) | $5–10 | Micro instance |
| AI Service (Hugging Face/GPU) | $50–150 | GPU recommended for inference |
| Database (Supabase Pro) | $25 | 8GB RAM, 10GB disk, PostGIS |
| Firebase Auth | $0–10 | 10K MAU free tier |
| Firebase Cloud Messaging | $0 | Free tier |
| OpenRouter (Gemini 2.0 Flash) | $5–20 | ~500 conversations/month |
| CI/CD (GitHub Actions) | $0 | 2,000 min/month free |
| Monitoring (Self-hosted) | $0–10 | Prometheus + Grafana |
| **Total (Low Usage)** | **~$30–50/month** | 100 users, 50 requests |
| **Total (Medium Usage)** | **~$50–100/month** | 1,000 users, 200 requests |
| **Total (High Usage)** | **~$100–200/month** | 10,000 users, 500 requests |

## A2.5 Test Coverage Summary

| Suite | Count | Coverage Areas |
|---|---|---|
| Flutter Unit Tests | 311 | Models, utils, providers, repositories, widgets, services |
| API Backend Tests | 50+ | Auth, validation, business logic, error handling |
| API Integration | 20+ | User lifecycle, request lifecycle, DB failure, Redis cache |
| API E2E | 20+ | Complete request → match → accept → verify flow |
| API Edge Cases | 14 | SQL injection, XSS, path traversal, malformed JSON, large payloads |
| Notification Backend | 8 | FCM dispatch, chunking, retry, stale token detection |
| AI Service | 15 | OCR extraction, plausibility, PII redaction, clinical safety |
| Load Tests | 10 | Baseline RPS, E2E latency, bottleneck isolation, horizontal scaling |

## A2.6 Tools and Frameworks Used

| Category | Tools |
|---|---|
| **Development** | VS Code, Git, GitHub, Postman |
| **Mobile** | Flutter SDK, Dart, Android Studio, Xcode |
| **Backend** | Node.js, npm, Express.js, Swagger/OpenAPI |
| **AI/ML** | Python, PyTorch, timm, Tesseract OCR, Jupyter Notebook |
| **Database** | Supabase CLI, pgAdmin, PostGIS |
| **DevOps** | Docker, Docker Compose, GitHub Actions, Render CLI |
| **Monitoring** | Prometheus, Grafana |
| **Testing** | Jest, Flutter Test, Pytest, k6 |
| **Security** | Gitleaks, OWASP ZAP |

## A2.7 Additional Screenshots

```
[Screenshot: Notification center screen]
Figure A2.1: Notification center showing push notification history.

[Screenshot: Stories screen]
Figure A2.2: Community stories screen showing donor experiences.

[Screenshot: Coupons screen]
Figure A2.3: Donor rewards coupons screen.

[Screenshot: Map discover screen]
Figure A2.4: Map view showing nearby hospitals and blood requests.

[Screenshot: Settings screen]
Figure A2.5: Application settings screen.
```

## A2.8 API Documentation

The full API documentation is available via Swagger UI when the API backend is running:

```
http://localhost:8090/api/docs
```

Or as raw OpenAPI JSON:

```
http://localhost:8090/api/docs.json
```
