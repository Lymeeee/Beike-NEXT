import 'package:flutter/foundation.dart';

import '/types/courses.dart';
import '/services/base.dart';

abstract class BaseCoursesService extends ChangeNotifier with BaseService {
  // Account Methods

  Future<void> doLogin(String cookie);

  Future<void> doLogout();

  Future<UserInfo> getUserInfo();

  Future<void> login(String cookie) async {
    await runLogin(() async {
      await doLogin(cookie);
    });
  }

  Future<void> logout() async {
    await runLogout(() async {
      if (kDebugMode) {
        print('Courses service logout called at base class');
      }
      await doLogout();
    });
  }

  // Data Methods

  Future<List<CourseGradeItem>> getGrades();

  GpaOverview? getCachedGpaOverview();

  Future<GpaOverview?> fetchGpaOverview();

  Future<List<ScoreDetail>> fetchScoreDetails(String rwid, String cjid);

  Future<List<ExamInfo>> getExams(TermInfo termInfo);

  Future<List<ClassItem>> getCurriculum(TermInfo termInfo);

  Future<List<ClassPeriod>> getCoursePeriods(TermInfo termInfo);

  Future<List<CalendarDay>> getCalendarDays(TermInfo termInfo);

  Future<List<CourseInfo>> getAllSelectedCourses(TermInfo termInfo);

  Future<List<CourseInfo>> getCoursesByTab(TermInfo termInfo, String tab);

  Future<List<CourseTab>> getCourseTabs(TermInfo termInfo);

  Future<List<TermInfo>> getTerms();

  Future<List<CourseInfo>> getCourseDetail(
    TermInfo termInfo,
    CourseInfo courseInfo,
  );

  Future<bool> sendCourseSelection(TermInfo termInfo, CourseInfo courseInfo);

  Future<bool> sendCourseDeselection(TermInfo termInfo, CourseInfo courseInfo);

  // Course Selection State Methods

  CourseSelectionState getCourseSelectionState();

  void updateCourseSelectionState(CourseSelectionState state);

  void addCourseToSelection(CourseInfo course);

  void removeCourseFromSelection(String courseId, [String? classId]);

  void setSelectionTermInfo(TermInfo termInfo);

  void clearCourseSelection();
}
