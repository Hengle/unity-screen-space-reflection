using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class HaltonSequence : MonoBehaviour
{
    void OnEnable()
    {
        var prefab = GameObject.CreatePrimitive(PrimitiveType.Cube);

        for (float i = 0; i < 100; i += 0.5f)
        {
            float x = i;
            float y = 0;
            float h = 1 / 3.0f;
            while (x > 0)
            {
                float digit = x % 2;
                x = (x - digit) * h;
                y = y + digit * h;
                h *= 0.5f;
            }

            Instantiate(prefab, new Vector3(y * 100, 0, 0), Quaternion.identity);
        }
    }


}
