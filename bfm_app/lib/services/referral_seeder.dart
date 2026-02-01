/// ---------------------------------------------------------------------------
/// File: lib/services/referral_seeder.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Seeds the referrals table with NZ support services from a curated list.
///
/// TODO: REMOVE THIS FILE - Pull referrals from backend instead once available.
///       This is a temporary solution to provide referral data while the
///       backend API is being developed.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Seeds referral data into the local database.
/// TODO: Remove this entire class and pull from backend instead.
class ReferralSeeder {
  /// Seeds referrals if the table is empty.
  /// TODO: Remove this method - use backend sync instead.
  static Future<void> seedIfEmpty() async {
    final db = await AppDatabase.instance.database;
    
    // Check if referrals already exist
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM referrals'),
    ) ?? 0;
    
    if (count > 0) {
      debugPrint('Referrals already seeded ($count rows), skipping.');
      return;
    }
    
    debugPrint('Seeding ${_seedData.length} referrals...');
    
    final nowIso = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final referral in _seedData) {
        await txn.insert('referrals', {
          ...referral,
          'is_active': 1,
          'updated_at': nowIso,
          'synced_at': nowIso,
        });
      }
    });
    
    debugPrint('Referral seeding complete.');
  }
  
  /// TODO: Remove this seed data - pull from backend instead.
  /// Source: NZ_Referral_Database_BFM_Chatbot.csv
  static const List<Map<String, dynamic>> _seedData = [
    // === Academic Support Services ===
    {
      'organisation_name': 'Waikato University - Student Learning Support',
      'category': 'Academic Support Services',
      'website': 'https://www.waikato.ac.nz/students/support-services/student-learning/',
      'phone': '07 838 4625',
      'services': 'Academic writing support, study skills workshops, assignment help, exam preparation, learning disability support',
      'demographics': 'University of Waikato students',
      'availability': 'Mon-Fri 8:30am-5pm during semester',
    },
    
    // === Addiction Support Services ===
    {
      'organisation_name': 'Gambling Helpline Aotearoa',
      'category': 'Addiction Support Services',
      'website': 'https://gamblinghelpline.co.nz/',
      'phone': '0800 654 655',
      'services': '24/7 support, information and referrals for gambling harm.',
      'demographics': 'People affected by gambling and their whānau',
      'availability': '24/7',
    },
    {
      'organisation_name': 'Problem Gambling Foundation (PGF)',
      'category': 'Addiction Support Services',
      'website': 'https://www.pgf.nz/',
      'phone': '0800 664 262',
      'services': 'Free confidential counselling and support for gambling harm; advice for families.',
      'demographics': 'People affected by gambling and their whānau',
      'availability': 'Office hours; check local services',
    },
    {
      'organisation_name': 'Samaritans',
      'category': 'Addiction Support Services',
      'website': 'https://www.samaritans.org.nz',
      'phone': '0800 726 666',
      'services': 'Emotional support, Suicide prevention, Befriending service',
      'demographics': 'All ages, People experiencing emotional distress',
      'availability': '24/7',
    },
    {
      'organisation_name': 'Alcohol Drug Helpline',
      'category': 'Addiction Support Services',
      'website': 'https://www.alcoholdrughelp.org.nz',
      'phone': '0800 787 797',
      'services': 'Addiction support, Information and advice, Referrals to treatment services',
      'demographics': 'People with addiction, Families affected by addiction',
      'availability': '24/7',
    },
    
    // === Banking Hardship ===
    {
      'organisation_name': 'ANZ – Financial Hardship',
      'category': 'Banking Hardship',
      'website': 'https://www.anz.co.nz/banking-with-anz/financial-hardship/',
      'phone': '0800 269 296',
      'services': 'Hardship assistance; loan restructuring; KiwiSaver significant hardship',
      'demographics': 'ANZ customers',
    },
    {
      'organisation_name': 'ASB – Financial Hardship Assistance',
      'category': 'Banking Hardship',
      'website': 'https://www.asb.co.nz/banking-with-asb/our-commitments-to-customers-in-financial-difficulty.html',
      'phone': '0800 27 27 35',
      'services': 'Hardship assistance; KiwiSaver significant hardship',
      'demographics': 'ASB customers',
    },
    {
      'organisation_name': 'BNZ – Financial Hardship',
      'category': 'Banking Hardship',
      'website': 'https://www.bnz.co.nz/support/everyday-accounts/managing-accounts/experiencing-financial-difficulty',
      'phone': '0800 275 269',
      'services': 'Hardship variations; support for loans/credit',
      'demographics': 'BNZ customers',
    },
    {
      'organisation_name': 'Kiwibank – Financial Hardship Assistance',
      'category': 'Banking Hardship',
      'website': 'https://www.kiwibank.co.nz/help/accounts/financial-support/financial-hardship-assistance/',
      'phone': '0800 272 273',
      'services': 'Hardship assistance for credit products; case-by-case',
      'demographics': 'Kiwibank customers',
    },
    {
      'organisation_name': 'Westpac – Financial Hardship',
      'category': 'Banking Hardship',
      'website': 'https://www.westpac.co.nz/personal/life-money/navigating-trying-times/financial-hardship/',
      'phone': '0800 772 771',
      'services': 'Hardship assistance; Financial Solutions team',
      'demographics': 'Westpac customers',
      'email': 'financial_solutions@westpac.co.nz',
    },
    {
      'organisation_name': 'TSB – Financial Assistance for Loans',
      'category': 'Banking Hardship',
      'website': 'https://www.tsb.co.nz/loans/financial-assistance',
      'phone': '0800 231 233',
      'services': 'Hardship assistance for loans; application form',
      'demographics': 'TSB customers',
    },
    
    // === Community & Emergency Support ===
    {
      'organisation_name': 'Auckland City Mission – Te Tāpui Atawhai',
      'category': 'Community & Emergency Support',
      'website': 'https://www.aucklandcitymission.org.nz/',
      'phone': '09 303 9200',
      'services': 'Emergency food, health services, housing support',
      'demographics': 'Auckland residents in need',
      'availability': 'Mon–Fri 8:30am–4:30pm',
      'address': '140 Hobson St, Auckland Central 1010',
    },
    {
      'organisation_name': 'Citizens Advice Bureau (CAB)',
      'category': 'Community & Emergency Support',
      'website': 'https://www.cab.org.nz/',
      'phone': '0800 367 222',
      'services': 'Free, confidential information & advice; referral to local services',
      'demographics': 'All NZ residents',
      'availability': 'Varies by branch',
      'region': 'National',
    },
    {
      'organisation_name': 'The Salvation Army – Get Help',
      'category': 'Community & Emergency Support',
      'website': 'https://www.salvationarmy.org.nz/get-help',
      'phone': '0800 53 00 00',
      'services': 'Emergency food, social services, budgeting & more',
      'demographics': 'People in need across NZ',
      'availability': 'Office hours; varies by centre',
      'region': 'National',
    },
    {
      'organisation_name': 'Wellington City Mission',
      'category': 'Foodbanks & Emergency Aid',
      'website': 'https://www.wm.org.nz',
      'phone': '04 384 7699',
      'services': 'Food bank, Emergency assistance, Social support',
      'demographics': 'Wellington residents in need',
      'availability': 'Mon-Fri 9am-4pm',
    },
    {
      'organisation_name': 'Red Cross',
      'category': 'Food Banks & Emergency Aid',
      'website': 'https://www.redcross.org.nz',
      'phone': '0800 733 276',
      'services': 'Emergency response, Disaster relief, Refugee support, Community services',
      'demographics': 'Disaster victims, Refugees, Community members',
      'availability': '24/7 emergency response',
    },
    
    // === Financial Mentoring ===
    {
      'organisation_name': 'MoneyTalks – National Helpline',
      'category': 'Financial Mentoring',
      'website': 'https://www.moneytalks.co.nz/',
      'phone': '0800 345 123',
      'services': 'Free financial helpline; connects to local services',
      'demographics': 'All NZ',
      'availability': 'Mon–Fri 8am–8pm; Sat 10am–2pm',
      'email': 'help@moneytalks.co.nz',
    },
    {
      'organisation_name': 'Bay Financial Mentors (Tau Awhi Noa)',
      'category': 'Financial Mentoring',
      'website': 'https://www.bfm.org.nz/',
      'phone': '0800 BFM 123',
      'services': 'Financial mentoring, debt management, Money Mates workshops',
      'demographics': 'Bay of Plenty residents',
      'availability': 'Mon–Fri office hours',
      'email': 'admin@bfm.org.nz',
      'address': 'Historic Village, 159 17th Ave, Tauranga South',
      'region': 'Bay of Plenty',
    },
    {
      'organisation_name': 'FinCap – Financial Mentoring Network',
      'category': 'Financial Mentoring',
      'website': 'https://www.fincap.org.nz/',
      'services': 'National support org for financial mentors; sector resources',
      'demographics': 'Financial mentoring services & public',
      'availability': 'Office hours',
      'email': 'kiaora@fincap.org.nz',
    },
    {
      'organisation_name': 'Christchurch Budget Service Trust',
      'category': 'Financial Mentoring',
      'website': 'https://www.christchurchbudget.org.nz/',
      'phone': '03 366 3422',
      'services': 'Free budgeting advice, debt management education',
      'demographics': 'Individuals & families in Christchurch',
      'availability': 'Mon–Fri business hours',
      'email': 'office@christchurchbudget.org.nz',
      'region': 'Canterbury',
    },
    
    // === Financial Education & Tools ===
    {
      'organisation_name': 'Sorted (CFFC)',
      'category': 'Financial Education & Tools',
      'website': 'https://sorted.org.nz',
      'phone': '0800 772 372',
      'services': 'Financial education, Budgeting tools, KiwiSaver guidance, Retirement planning',
      'demographics': 'All ages, General public',
      'availability': '24/7 online tools',
    },
    {
      'organisation_name': 'Commission for Financial Capability',
      'category': 'Financial Education & Tools',
      'website': 'https://www.cffc.org.nz',
      'phone': '04 474 0470',
      'services': 'Financial education, Research and policy, MoneyWeek coordination',
      'demographics': 'All ages, Educators, Policy makers',
      'availability': 'Mon-Fri 9am-5pm',
    },
    
    // === Government Financial Support ===
    {
      'organisation_name': 'StudyLink',
      'category': 'Government Financial Support',
      'website': 'https://www.studylink.govt.nz',
      'phone': '0800 88 99 00',
      'services': 'Student loans, Student allowances, Accommodation supplement, Course fees, Course-related costs',
      'demographics': 'Students, Apprentices',
      'availability': '24/7 online, Mon-Fri 8am-6pm phone',
    },
    {
      'organisation_name': 'Work and Income (MSD)',
      'category': 'Government Financial Support',
      'website': 'https://www.workandincome.govt.nz',
      'phone': '0800 559 009',
      'services': 'Jobseeker support, Sole parent support, Supported living payment, Emergency assistance, Special needs grants',
      'demographics': 'Unemployed, Parents, Disabled, General public',
      'availability': 'Mon-Fri 8:30am-5pm',
    },
    {
      'organisation_name': 'Inland Revenue (IRD)',
      'category': 'Government Financial Support',
      'website': 'https://www.ird.govt.nz',
      'phone': '0800 227 774',
      'services': 'Working for Families, Best Start, Winter Energy Payment, KiwiSaver, Tax refunds',
      'demographics': 'Families, Working people, Retirees',
      'availability': 'Mon-Fri 8am-8pm',
    },
    {
      'organisation_name': 'Accommodation Supplement (MSD)',
      'category': 'Government Financial Support',
      'website': 'https://www.workandincome.govt.nz/products/a-z-benefits/accommodation-supplement.html',
      'phone': '0800 559 009',
      'services': 'Rent assistance, Board assistance, Temporary accommodation supplement',
      'demographics': 'Renters, Boarders, Low-income earners',
      'availability': 'Mon-Fri 8:30am-5pm',
    },
    
    // === Mental Health Helplines ===
    {
      'organisation_name': '1737 - Need to Talk?',
      'category': 'Mental Health Helpline',
      'website': 'https://1737.org.nz',
      'phone': '1737',
      'services': 'Free 24/7 mental health and wellbeing support, Text and phone counselling',
      'demographics': 'All ages, General public',
      'availability': '24/7',
    },
    {
      'organisation_name': 'Lifeline',
      'category': 'Mental Health Helpline',
      'website': 'https://www.lifeline.org.nz',
      'phone': '0800 543 354',
      'services': 'Crisis support, Suicide prevention, Mental health first aid training',
      'demographics': 'All ages, People in crisis',
      'availability': '24/7',
    },
    {
      'organisation_name': 'Depression Helpline',
      'category': 'Mental Health Helpline',
      'website': 'https://depression.org.nz',
      'phone': '0800 111 757',
      'services': 'Depression support, Information and resources, Referrals',
      'demographics': 'People with depression, Families and friends',
      'availability': '24/7',
    },
    {
      'organisation_name': 'Suicide Crisis Helpline',
      'category': 'Mental Health Helpline',
      'website': 'https://www.lifeline.org.nz/services/suicide-crisis-helpline',
      'phone': '0508 828 865',
      'services': 'Free nationwide suicide crisis support; operated by trained practitioners.',
      'demographics': 'All NZ',
      'availability': '24/7',
    },
    
    // === Youth Support ===
    {
      'organisation_name': 'Youthline',
      'category': 'Youth Support',
      'website': 'https://www.youthline.co.nz/',
      'phone': '0800 376 633',
      'services': '24/7 crisis support, text and online chat counselling, youth mental health programmes, suicide prevention',
      'demographics': 'Young people aged 12-25, families',
      'availability': '24/7 phone, text 234, online chat',
    },
    {
      'organisation_name': "0800 What's Up (Barnardos)",
      'category': 'Youth Support',
      'website': 'https://whatsup.co.nz/',
      'phone': '0800 942 8787',
      'services': 'Free counselling for children and teens via phone and online chat.',
      'demographics': 'Ages 5–18',
      'availability': 'Phone 11am–11pm daily; chat 11am–10:30pm daily',
    },
    
    // === Family Violence Support ===
    {
      'organisation_name': 'Are You OK – Family Violence Info Line',
      'category': 'Family Violence Support',
      'website': 'https://www.areyouok.org.nz/',
      'phone': '0800 456 450',
      'services': 'Free, confidential advice and referrals re: family violence; phone and live chat available 24/7.',
      'demographics': 'All NZ',
      'availability': '24/7',
    },
    {
      'organisation_name': "Women's Refuge – Crisisline",
      'category': 'Family Violence Support',
      'phone': '0800 733 843',
      'services': '24/7 crisis line for immediate support and safe accommodation.',
      'demographics': 'Women and children experiencing domestic violence',
      'availability': '24/7',
    },
    {
      'organisation_name': 'Shine Domestic Abuse Helpline',
      'category': 'Family Violence Support',
      'website': 'https://2shine.org.nz/what-we-do/shine-helpline',
      'phone': '0508 744 633',
      'services': '24/7 confidential domestic abuse helpline; phone and webchat options.',
      'availability': '24/7',
    },
    
    // === Housing Support ===
    {
      'organisation_name': 'Kāinga Ora – Homes and Communities',
      'category': 'Housing Support',
      'website': 'https://kaingaora.govt.nz/',
      'phone': '0800 801 601',
      'services': 'State/social housing provider; manages public housing and developments; tenant support.',
      'demographics': 'People eligible for public housing',
      'availability': 'Office hours',
      'email': 'enquiries1@kaingaora.govt.nz',
    },
    {
      'organisation_name': 'Tenancy Services (MBIE)',
      'category': 'Housing Support',
      'website': 'https://www.tenancy.govt.nz/',
      'services': 'Official information on tenant/landlord rights; bond lodgement; Healthy Homes; mediation; Tenancy Tribunal applications.',
      'demographics': 'Tenants & landlords in NZ',
      'availability': 'Online 24/7; office hours for phone support',
    },
    {
      'organisation_name': 'Housing New Zealand',
      'category': 'Housing Support',
      'website': 'https://www.hnzc.co.nz',
      'phone': '0800 801 601',
      'services': 'Social housing, Income-related rent, Emergency housing, Housing support',
      'demographics': 'Low-income families, Homeless, Priority housing needs',
      'availability': 'Mon-Fri 8am-5pm',
    },
    
    // === Legal Support ===
    {
      'organisation_name': 'Community Law',
      'category': 'Legal Support',
      'website': 'https://www.communitylaw.org.nz',
      'phone': '0800 999 999',
      'services': 'Free legal advice, Legal education, Court support, Advocacy',
      'demographics': 'Low-income earners, General public',
      'availability': 'Varies by centre',
    },
    {
      'organisation_name': 'Tenancy Tribunal',
      'category': 'Legal Support',
      'website': 'https://www.tenancy.govt.nz',
      'phone': '0800 836 262',
      'services': 'Tenancy dispute resolution, Rental bond services, Tenancy information',
      'demographics': 'Tenants, Landlords',
      'availability': 'Mon-Fri 8am-6pm',
    },
    
    // === Microfinance ===
    {
      'organisation_name': 'Good Shepherd NZ – Good Loans',
      'category': 'Microfinance',
      'website': 'https://goodshepherd.org.nz/get-support/our-services/loans/',
      'phone': '0800 466 370',
      'services': 'No-interest loans (Good Loans) & debt solutions',
      'demographics': 'Low-income individuals & whānau',
      'availability': 'Office hours',
      'email': 'support@goodshepherd.org.nz',
    },
    {
      'organisation_name': 'Ngā Tāngata Microfinance',
      'category': 'Microfinance',
      'website': 'https://www.ngatangatamicrofinance.org.nz/',
      'services': 'Interest-free GetAhead and GetControl loans via mentors',
      'demographics': 'Low-income individuals via budgeting services',
      'availability': 'Office hours',
      'email': 'info@ntm.org.nz',
    },
    
    // === Māori & Iwi Support ===
    {
      'organisation_name': 'Te Puni Kōkiri (Ministry of Māori Development)',
      'category': 'Māori & Iwi Support',
      'website': 'https://www.tpk.govt.nz/',
      'phone': '04 819 6000',
      'services': 'Māori development funding, regional support, policy advice',
      'demographics': 'Māori whānau, hapū, iwi, Māori organisations',
      'availability': 'Mon–Fri 8:30am–5pm',
      'email': 'info@tpk.govt.nz',
    },
    {
      'organisation_name': 'Whānau Ora',
      'category': 'Māori & Pacific Support',
      'website': 'https://www.whanauora.nz',
      'phone': '0800 946 2622',
      'services': 'Whānau-centred support, Health and social services, Cultural programmes',
      'demographics': 'Māori and Pacific whānau',
      'availability': '24/7 helpline',
    },
    {
      'organisation_name': 'Waikato-Tainui – Grants & Scholarships',
      'category': 'Māori & Iwi Support',
      'website': 'https://waikatotainui.com/grants/',
      'phone': '0800 824 684',
      'services': 'Education, kaumātua, innovation and environment grants',
      'demographics': 'Registered Waikato-Tainui tribal members',
    },
    {
      'organisation_name': 'Māori Women\'s Development Inc. (MWDI)',
      'category': 'Māori Business Development',
      'website': 'https://mwdi.co.nz/',
      'phone': '04 499 6504',
      'services': 'Micro-loans, business coaching, financial capability for wāhine Māori',
      'demographics': 'Wāhine Māori entrepreneurs',
      'availability': 'Office hours',
      'email': 'mwdi@mwdi.co.nz',
    },
    
    // === Student Support ===
    {
      'organisation_name': 'University of Auckland – Student Emergency Fund',
      'category': 'Student Hardship',
      'website': 'https://www.auckland.ac.nz/en/study/fees-and-money-matters/financial-support/hardship-support.html',
      'services': 'Student emergency hardship fund',
      'demographics': 'University of Auckland students',
      'region': 'National',
    },
    {
      'organisation_name': 'Victoria University – Hardship Fund',
      'category': 'Student Hardship',
      'website': 'https://www.wgtn.ac.nz/students/money/hardship-fund',
      'services': 'Hardship Fund & Equity Grants',
      'demographics': 'All VUW students',
      'region': 'National',
    },
    {
      'organisation_name': 'Student Job Search (SJS)',
      'category': 'Student Support & Employment',
      'website': 'https://www.sjs.co.nz/',
      'services': 'Jobs and employment support for tertiary students and recent graduates.',
      'demographics': 'Tertiary students and graduates (NZ)',
      'availability': 'Online',
    },
    {
      'organisation_name': 'Hardship Fund for Learners (HAFL) – TEC',
      'category': 'Student Hardship',
      'website': 'https://www.tec.govt.nz/about-us/about-us/news-and-consultations/news-and-consultations/archived-news/hafl-supports-teos-to-provide-temporary-financial-assistance',
      'services': 'Government fund (via TEOs) that provides temporary financial assistance to currently enrolled domestic students facing hardship.',
      'demographics': 'Currently enrolled domestic students',
    },
    
    // === Health ===
    {
      'organisation_name': 'Healthline',
      'category': 'Health Helpline',
      'website': 'https://www.healthline.govt.nz',
      'phone': '0800 611 116',
      'services': '24/7 health advice, Nurse consultation, Health information',
      'demographics': 'All residents',
      'availability': '24/7',
    },
    {
      'organisation_name': 'Family Planning',
      'category': 'Sexual Health',
      'website': 'https://www.familyplanning.org.nz',
      'phone': '0800 372 5463',
      'services': 'Reproductive health, Contraception, Sexual health education',
      'demographics': 'All ages, Focus on reproductive health',
      'availability': 'Clinic hours vary',
    },
    
    // === LGBTQI+ Support ===
    {
      'organisation_name': 'OUTLine NZ',
      'category': 'LGBTQI+ Support',
      'website': 'https://outline.org.nz/',
      'phone': '0800 688 5463',
      'services': 'LGBTQI+ support line, counselling, community support, crisis intervention',
      'demographics': 'LGBTQI+ individuals, rainbow youth, students',
      'availability': 'Daily 6pm-9pm',
    },
    {
      'organisation_name': 'RainbowYOUTH',
      'category': 'LGBTQI+ Support',
      'website': 'https://www.ry.org.nz/',
      'phone': '09 376 4155',
      'services': 'LGBTQI+ youth support, peer support groups, advocacy, education',
      'demographics': 'LGBTQI+ youth aged 13-27',
      'availability': 'Office hours vary, support groups weekly',
    },
    
    // === Disability Support ===
    {
      'organisation_name': 'CCS Disability Action',
      'category': 'Disability Support',
      'website': 'https://www.ccsdisabilityaction.org.nz/',
      'phone': '0800 227 200',
      'services': 'Disability support services, advocacy, equipment services, education support',
      'demographics': 'People with disabilities, students with disabilities',
      'availability': 'Mon-Fri 8:30am-5pm',
    },
    {
      'organisation_name': 'Deaf Aotearoa',
      'category': 'Disability Support',
      'website': 'https://deaf.org.nz/',
      'phone': '0800 332 322',
      'services': 'Deaf community support, NZSL interpreting, advocacy, education support',
      'demographics': 'Deaf and hard of hearing individuals, students',
      'availability': 'Mon-Fri 8:30am-5pm',
    },
    
    // === Rural Support ===
    {
      'organisation_name': 'Rural Support Trust',
      'category': 'Rural Community Support',
      'website': 'https://www.ruralsupport.org.nz/',
      'phone': '0800 787 254',
      'services': 'Rural wellbeing support, crisis assistance, counselling, financial assistance, peer support',
      'demographics': 'Rural communities, farmers, farm workers, rural students',
      'availability': '24/7 helpline, regional coordinators nationwide',
    },
    
    // === Senior Services ===
    {
      'organisation_name': 'Grey Power',
      'category': 'Senior Services',
      'website': 'https://www.greypower.co.nz',
      'phone': '04 473 2202',
      'services': 'Advocacy for seniors, Policy representation, Member benefits',
      'demographics': 'Seniors 50+',
      'availability': 'Mon-Fri 9am-5pm',
    },
    
    // === Employment ===
    {
      'organisation_name': 'Careers New Zealand',
      'category': 'Education & Employment',
      'website': 'https://www.careers.govt.nz',
      'phone': '0800 222 733',
      'services': 'Career guidance, Job market information, Skills assessment, Training pathways',
      'demographics': 'All ages, Career changers, Students',
      'availability': '24/7 online, phone hours vary',
    },
    {
      'organisation_name': 'MSD Employment Services',
      'category': 'Employment',
      'website': 'https://www.workandincome.govt.nz/products/find-a-job',
      'phone': '0800 559 009',
      'services': 'Job search support, Skills training, CV assistance, Interview preparation',
      'demographics': 'Job seekers, Unemployed',
      'availability': 'Mon-Fri 8:30am-5pm',
    },
    
    // === Student Banking ===
    {
      'organisation_name': 'ANZ - Student Banking',
      'category': 'Student Financial Services',
      'website': 'https://www.anz.co.nz/personal/accounts/jumpstart/',
      'phone': '0800 269 296',
      'services': 'Fee-free student accounts, overdraft facilities, budgeting tools, financial education',
      'demographics': 'Students aged 13-25',
      'availability': 'Branch hours vary, 24/7 online banking',
    },
    {
      'organisation_name': 'Kiwibank - Student Services',
      'category': 'Student Financial Services',
      'website': 'https://www.kiwibank.co.nz/personal-banking/young-people/',
      'phone': '0800 113 355',
      'services': 'Fee-free youth accounts, student banking, savings goals, financial education resources',
      'demographics': 'Students, young people aged 13-25',
      'availability': 'Nationwide branches, 24/7 online banking',
    },
    
    // === Youth & Family Services ===
    {
      'organisation_name': 'Oranga Tamariki',
      'category': 'Youth & Family Services',
      'website': 'https://www.orangatamariki.govt.nz',
      'phone': '0508 326 459',
      'services': 'Child protection, Family support, Youth justice, Care services',
      'demographics': 'Children, young people, families',
      'availability': '24/7 contact centre',
    },
  ];
}
