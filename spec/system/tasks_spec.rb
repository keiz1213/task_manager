require 'rails_helper'

RSpec.describe "Tasks" do
  describe 'タスクのCRUD' do
    it 'タスクの作成' do
      visit root_path

      expect {
        click_link '新規タスク'
        fill_in 'タイトル', with: 'test-task'
        fill_in '説明', with: 'test'
        choose '中'
        fill_in '締め切り', with: Time.mktime(2100, 1, 2, 3, 4)
        click_button '登録'
        expect(page).to have_content('タスク: test-taskを作成しました')
        expect(page).to have_content('tasks#index!')
        expect(page).to have_content('test-task')
        expect(page).to have_content('重要度: 中')
        expect(page.find(:test, 'update-state').value).to eq 'ステータス: 未着手'
        expect(page).to have_content("締め切り: 2100/01/02 03:04")
      }.to change(Task, :count).by(1)
    end

    it 'タスクの一覧が作成日の降順で表示される' do
      today_task_title = create(:task).title
      yesterday_task_title = create(:task, :yesterday_task).title
      day_before_yesterday_task_title = create(:task, :day_before_yesterday_task).title
      visit root_path

      within(:test, 'task-list') do
        task_titles = all(:test, 'task-title')
        expect(task_titles.count).to be 3
        expect(task_titles[0].text).to eq today_task_title
        expect(task_titles[1].text).to eq yesterday_task_title
        expect(task_titles[2].text).to eq day_before_yesterday_task_title
      end
    end

    it 'タスクの詳細' do
      task = create(:task)

      visit root_path
      click_link task.title
      expect(page).to have_content(task.title)
      expect(page).to have_content(task.description)
      expect(page).to have_content('低')
      expect(page).to have_content('2100/01/02 03:04')
      expect(page).to have_content('未着手')
    end

    it 'タスクの更新' do
      task = create(:task)
      visit root_path

      expect {
        click_link task.title
        click_link '編集'
        fill_in 'タイトル', with: 'foo'
        choose '高'
        fill_in '締め切り', with: Time.mktime(2200, 1, 2, 3, 4)
        click_button '更新する'
        expect(page).to have_content('foo')
        expect(page).to have_content('タスク: fooを更新しました')
        expect(page).to have_content('tasks#index!')
        expect(page).to have_content('foo')
        expect(page).to have_content('重要度: 高')
        expect(page.find(:test, 'update-state').value).to eq 'ステータス: 未着手'
        expect(page).to have_content('締め切り: 2200/01/02 03:04')
      }.not_to change(Task, :count)
    end

    it 'タスクの削除' do
      task = create(:task)
      visit root_path

      expect {
        accept_confirm do
          click_link '削除'
        end
        expect(page).to have_content("タスク: #{task.title}を削除しました")
        expect(page).to have_content('tasks#index!')
      }.to change(Task, :count).by(-1)
    end
  end

  describe 'ソート' do
    it '締切に近い順に並び替える' do
      due_tomorrow_task_title = create(:task, :due_tomorrow_task).title
      due_two_days_after_tomorrow_task_title = create(:task, :due_two_days_after_tomorrow_task).title
      due_day_after_tomorrow_task_title = create(:task, :due_day_after_tomorrow_task).title

      visit root_path
      click_link '締切が近い順'

      # 設定ファイル: spec/support/wait_for_css
      # 参考: https://qiita.com/johnslith/items/09bb0e5257e06a4bd948
      wait_for_css_appear('.task-card') do
        within(:test, 'task-list') do
          task_titles = all(:test, 'task-title')
          expect(task_titles.count).to be 3
          expect(task_titles[0].text).to eq due_tomorrow_task_title
          expect(task_titles[1].text).to eq due_day_after_tomorrow_task_title
          expect(task_titles[2].text).to eq due_two_days_after_tomorrow_task_title
        end
      end
    end
  end

  describe '検索' do
    describe 'キーワード検索' do
      it 'タイトルからキーワード検索できる' do
        create(:task, title: '青りんご')
        create(:task, title: 'スイカ')
        create(:task, title: 'メロン')
        create(:task, title: 'りんごちゃん')
        create(:task, title: 'パイナップル')

        visit root_path
        fill_in 'キーワード', with: 'りんご'
        click_button '検索する'
        wait_for_css_appear('.task-card') do
          within(:test, 'task-list') do
            task_titles = all(:test, 'task-title')
            expect(task_titles.count).to be 2
            task_titles.each do |el|
              expect(el.text).to match(/青りんご|りんごちゃん/)
            end
          end
        end
      end

      it '説明からキーワード検索できる' do
        create(:task, title: '青りんご', description: 'バナナ')
        create(:task, title: 'スイカ', description: '桃太郎')
        create(:task, title: 'メロン', description: 'いちごみるく')
        create(:task, title: 'りんごちゃん', description: 'いちご摘み')
        create(:task, title: 'パイナップル', description: 'いちご')

        visit root_path
        fill_in 'キーワード', with: '桃'
        click_button '検索する'
        wait_for_css_appear('.task-card') do
          task_titles = []
          within(:test, 'task-list') do
            task_titles = all(:test, 'task-title')
            expect(task_titles.count).to be 1
          end
          click_link task_titles[0].text
          expect(page).to have_content('桃太郎')
        end
      end

      it '検索結果を締切が近い順にソートできる' do
        create(:task, title: '青りんご', description: 'バナナ', deadline: Time.current.since(5.days))
        create(:task, title: 'スイカ', description: '桃太郎', deadline: Time.current.since(3.days))
        create(:task, title: 'メロン', description: 'いちごミルク', deadline: Time.current.since(2.days))
        create(:task, title: 'りんごちゃん', description: 'いちご摘み', deadline: Time.current.since(4.days))
        create(:task, title: 'パイナップル', description: 'いちご', deadline: Time.current.since(1.day))

        visit root_path
        fill_in 'キーワード', with: 'いちご'
        click_button '検索する'
        click_link '締切が近い順'
        wait_for_css_appear('.task-card') do
          within(:test, 'task-list') do
            task_titles = all(:test, 'task-title')
            expect(task_titles.count).to be 3
            task_titles.each do |el|
              expect(el.text).to match(/パイナップル|メロン|りんごちゃん/)
            end
            expect(task_titles[0].text).to eq 'パイナップル'
            expect(task_titles[1].text).to eq 'メロン'
            expect(task_titles[2].text).to eq 'りんごちゃん'
          end
        end
      end

      it '検索結果をステータスで絞り込める' do
        create(:task, title: '青りんご', state: 'done')
        create(:task, title: '毒りんご', state: 'not_started')
        create(:task, title: 'りんごの木', state: 'not_started')
        create(:task, title: '私はりんごが好きです', state: 'in_progress')
        create(:task, title: 'パイナップル', state: 'in_progress')
        create(:task, title: 'ぶどう', state: 'in_progress')

        visit root_path
        fill_in 'キーワード', with: 'りんご'
        click_button '検索する'
        click_link '未着手のタスク'
        wait_for_css_appear('.task-card') do
          within(:test, 'task-list') do
            task_titles = all(:test, 'task-title')
            expect(task_titles.count).to be 2
            task_titles.each do |el|
              expect(el.text).to match(/毒りんご|りんごの木/)
            end
          end
        end
      end

      it '検索結果をステータスで絞り込み、それを締め切りに近い順に並び替える' do
        create(:task, title: '青りんご', state: 'done', deadline: Time.current.since(6.days))
        create(:task, title: '毒りんご', state: 'not_started', deadline: Time.current.since(4.days))
        create(:task, title: 'りんごの木', state: 'not_started', deadline: Time.current.since(1.day))
        create(:task, title: '私はりんごが好きです', state: 'not_started', deadline: Time.current.since(5.days))
        create(:task, title: 'パイナップル', state: 'in_progress', deadline: Time.current.since(2.days))
        create(:task, title: 'ぶどう', state: 'in_progress', deadline: Time.current.since(3.days))

        visit root_path
        fill_in 'キーワード', with: 'りんご'
        click_button '検索する'
        click_link '未着手のタスク'
        click_link '締切が近い順'
        wait_for_css_appear('.task-card') do
          within(:test, 'task-list') do
            task_titles = all(:test, 'task-title')
            expect(task_titles.count).to be 3
            task_titles.each do |el|
              expect(el.text).to match(/毒りんご|りんごの木|私はりんごが好きです/)
            end
            expect(task_titles[0].text).to eq 'りんごの木'
            expect(task_titles[1].text).to eq '毒りんご'
            expect(task_titles[2].text).to eq '私はりんごが好きです'
          end
        end
      end
    end

    describe 'ステータス検索' do
      it '未着手のタスクを検索できる' do
        create(:task, title: '青りんご', state: 'done')
        create(:task, title: 'スイカ', state: 'not_started')
        create(:task, title: 'メロン', state: 'not_started')
        create(:task, title: 'みかん', state: 'in_progress')
        create(:task, title: 'パイナップル', state: 'in_progress')
        create(:task, title: 'ぶどう', state: 'in_progress')

        visit root_path
        click_link '未着手のタスク'
        wait_for_css_appear('.task-card') do
          within(:test, 'task-list') do
            task_titles = all(:test, 'task-title')
            expect(task_titles.count).to be 2
            task_titles.each do |el|
              expect(el.text).to match(/スイカ|メロン/)
            end
          end
        end
      end

      it '着手中のタスクを検索できる' do
        create(:task, title: '青りんご', state: 'done')
        create(:task, title: 'スイカ', state: 'not_started')
        create(:task, title: 'メロン', state: 'not_started')
        create(:task, title: 'みかん', state: 'in_progress')
        create(:task, title: 'パイナップル', state: 'in_progress')
        create(:task, title: 'ぶどう', state: 'in_progress')

        visit root_path
        click_link '着手しているタスク'
        wait_for_css_appear('.task-card') do
          within(:test, 'task-list') do
            task_titles = all(:test, 'task-title')
            expect(task_titles.count).to be 3
            task_titles.each do |el|
              expect(el.text).to match(/みかん|パイナップル|ぶどう/)
            end
          end
        end
      end

      it '完了したタスクを検索できる' do
        create(:task, title: '青りんご', state: 'done')
        create(:task, title: 'スイカ', state: 'not_started')
        create(:task, title: 'メロン', state: 'not_started')
        create(:task, title: 'みかん', state: 'in_progress')
        create(:task, title: 'パイナップル', state: 'in_progress')
        create(:task, title: 'ぶどう', state: 'in_progress')

        visit root_path
        click_link '完了したタスク'
        wait_for_css_appear('.task-card') do
          within(:test, 'task-list') do
            task_titles = all(:test, 'task-title')
            expect(task_titles.count).to be 1
            task_titles.each do |el|
              expect(el.text).to match(/青りんご/)
            end
          end
        end
      end

      it '検索結果を締め切りが近い順にソートできる' do
        create(:task, title: '青りんご', state: 'done', deadline: Time.current.since(6.days))
        create(:task, title: 'スイカ', state: 'not_started', deadline: Time.current.since(4.days))
        create(:task, title: 'メロン', state: 'not_started', deadline: Time.current.since(1.day))
        create(:task, title: 'みかん', state: 'in_progress', deadline: Time.current.since(5.days))
        create(:task, title: 'パイナップル', state: 'in_progress', deadline: Time.current.since(2.days))
        create(:task, title: 'ぶどう', state: 'in_progress', deadline: Time.current.since(3.days))

        visit root_path
        click_link '着手しているタスク'
        click_link '締切が近い順'
        wait_for_css_appear('.task-card') do
          within(:test, 'task-list') do
            task_titles = all(:test, 'task-title')
            expect(task_titles.count).to be 3
            task_titles.each do |el|
              expect(el.text).to match(/パイナップル|ぶどう|みかん/)
            end
            expect(task_titles[0].text).to eq 'パイナップル'
            expect(task_titles[1].text).to eq 'ぶどう'
            expect(task_titles[2].text).to eq 'みかん'
          end
        end
      end
    end
  end

  describe 'タスクのステータス更新' do
    context '現在のステータスが「未着手」の時' do
      it 'ステータスが「着手」に更新される' do
        create(:task)

        visit root_path
        expect(find(:test, 'update-state').value).to eq 'ステータス: 未着手'
        click_button 'ステータス: 未着手'
        # TODO
        sleep(2)
        expect(find(:test, 'update-state').value).to eq 'ステータス: 着手'
      end
    end

    context '現在のステータスが「着手」の時' do
      it 'ステータスが「完了」に更新される' do
        create(:task, state: 'in_progress')

        visit root_path
        expect(find(:test, 'update-state').value).to eq 'ステータス: 着手'
        click_button 'ステータス: 着手'
        # TODO
        sleep(2)
        expect(find(:test, 'update-state').value).to eq 'ステータス: 完了'
      end
    end

    context '現在のステータスが「完了」の時' do
      it 'ステータスが「未着手」に更新される' do
        create(:task, state: 'done')

        visit root_path
        expect(find(:test, 'update-state').value).to eq 'ステータス: 完了'
        click_button 'ステータス: 完了'
        # TODO
        sleep(2)
        expect(find(:test, 'update-state').value).to eq 'ステータス: 未着手'
      end
    end
  end
end
