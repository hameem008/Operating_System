#include <bits/stdc++.h>
#include <pthread.h>
#include <semaphore.h>
#include <unistd.h>
using namespace std;
#define endl '\n'
#define gallery1_capacity 5
#define corridor_capacity 3
#define booth_capacity 3

// testcases
// 5 5 3 4 2 5
// 7 6 1 2 4 3

int N, M, w, x, y, z;         // input variable
int std_cnt = 0, prm_cnt = 0; // standard and premium counter
sem_t sem_print, sem_st1, sem_st2, sem_st3, sem_gallery1, sem_corridor, sem_boothaccess, sem_boothoccupied, sem_booth;
sem_t sem_std, sem_prm;
auto start_time = chrono::steady_clock::now();

class Visitor
{
private:
    int ID;

public:
    void setID(int ID)
    {
        this->ID = ID;
    }
    int getID()
    {
        return ID;
    }
};

// poisson random number
int random(int lower_limit, int upper_limit)
{
    random_device rd;
    mt19937 generator(rd());
    double lambda = (upper_limit + lower_limit) / 2;
    poisson_distribution<int> poissonDist(lambda);
    return poissonDist(generator);
}

void print(int id, string str)
{
    auto now = chrono::steady_clock::now();
    auto elapsed = chrono::duration_cast<chrono::seconds>(now - start_time).count();
    sem_wait(&sem_print);
    cout << "Visitor " << id << " " << str << " at timestamp " << elapsed << endl;
    sem_post(&sem_print);
}

void *visiting(void *arg)
{
    Visitor *vs = (Visitor *)arg; // argument
    sleep(random(2, 4));          // random sleep before entry
    print(vs->getID(), "has arrived at A");
    sleep(w); // time spend in hallway
    print(vs->getID(), "has arrived at B");
    sem_wait(&sem_st1); // locking step 1
    print(vs->getID(), "is at step 1");
    sleep(random(1, 2));
    sem_wait(&sem_st2); // locking step 2
    sem_post(&sem_st1); // releasing step 1 after locking step 2
    print(vs->getID(), "is at step 2");
    sleep(random(1, 2));
    sem_wait(&sem_st3); // locking step 3
    sem_post(&sem_st2); // releasing step 2 after locking step 3
    print(vs->getID(), "is at step 3");
    sleep(random(1, 2));
    sem_wait(&sem_gallery1); // entering Gallery 1 by locking 
    sem_post(&sem_st3); // releasing step 3 after entering Gallery 1
    print(vs->getID(), "is at C (entered Gallery 1)");
    sleep(x);   // time spend in Gallery 1
    print(vs->getID(), "is at D (exiting Gallery 1)");
    sem_wait(&sem_corridor);    // entering Glass Corridor by locking 
    sem_post(&sem_gallery1);    // releasing Gallery 1 after entering Glass Corridor
    sleep(random(2, 3));    // time spend in Glass Corridor
    print(vs->getID(), "is at E (entered Gallery 2)");
    sem_post(&sem_corridor); // releasing Glass Corridor after entering Gallery 2
    sleep(y);   // time spend in Gallery 2
    print(vs->getID(), "is about to enter the photo booth");    // ready to go to photo booth
    if (vs->getID() / 1000 == 1)
    {
        // locking access
        sem_wait(&sem_boothaccess); 
        sem_wait(&sem_std);
        std_cnt++;
        if (std_cnt == 1)
        {
            sem_wait(&sem_boothoccupied);   // after entering a standard user no premium can enter but another standard user can enter
        }
        sem_post(&sem_std);
        sem_post(&sem_boothaccess);
        sem_wait(&sem_booth);
        print(vs->getID(), "is inside the photo booth");
        sleep(random(2, 4));    // time spend in photo booth
        print(vs->getID(), "is at F (exited Photo Booth)");
        sem_post(&sem_booth);
        sem_wait(&sem_std);
        std_cnt--;
        if (std_cnt == 0)
        {
            sem_post(&sem_boothoccupied);  
        }
        sem_post(&sem_std);
    }
    else if (vs->getID() / 1000 == 2)
    {
        sem_wait(&sem_prm);
        prm_cnt++;
        if (prm_cnt == 1)
        {
            sem_wait(&sem_boothaccess); // after entering a premium user no user can enter 
        }
        sem_post(&sem_prm);
        sem_wait(&sem_boothoccupied); // current premium user is using
        print(vs->getID(), "is inside the photo booth");
        sleep(random(2, 4));    // time spend in photo booth
        print(vs->getID(), "is at F (exited Photo Booth)");
        sem_post(&sem_boothoccupied);   // another premium user can use the booth now
        sem_wait(&sem_prm);
        prm_cnt--;
        if (prm_cnt == 0)
        {
            sem_post(&sem_boothaccess); // other standard user can use the booth now
        }
        sem_post(&sem_prm);
    }
    return nullptr;
}

int main()
{
    cin >> N >> M >> w >> x >> y >> z;
    int n = N + M;
    vector<Visitor> visitors(n);  // threads data
    vector<pthread_t> threads(n); // all threads
    for (int i = 0; i < N + M; i++)
    {
        if (i < N)
            visitors[i].setID(1000 + i + 1);
        else
            visitors[i].setID(2000 + i - N + 1);
    }
    // initializing all semaphore
    sem_init(&sem_print, 0, 1);
    sem_init(&sem_st1, 0, 1);
    sem_init(&sem_st2, 0, 1);
    sem_init(&sem_st3, 0, 1);
    sem_init(&sem_gallery1, 0, gallery1_capacity);
    sem_init(&sem_corridor, 0, corridor_capacity);
    sem_init(&sem_boothaccess, 0, 1);
    sem_init(&sem_boothoccupied, 0, 1);
    sem_init(&sem_booth, 0, booth_capacity);
    sem_init(&sem_std, 0, 1);
    sem_init(&sem_prm, 0, 1);
    start_time = chrono::steady_clock::now();
    for (int i = 0; i < n; i++)
    {
        // creating threads
        pthread_create(&threads[i], nullptr, visiting, (void *)&visitors[i]);
    }
    for (int i = 0; i < n; i++)
    {
        // join
        pthread_join(threads[i], nullptr);
    }
    return 0;
}